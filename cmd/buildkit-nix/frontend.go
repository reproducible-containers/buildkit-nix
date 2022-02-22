package main

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/AkihiroSuda/buildkit-nix/pkg/refutil"
	"github.com/docker/distribution/reference"
	"github.com/moby/buildkit/client/llb"
	"github.com/moby/buildkit/exporter/containerimage/exptypes"
	"github.com/moby/buildkit/frontend/dockerfile/dockerfile2llb"
	"github.com/moby/buildkit/frontend/dockerfile/dockerignore"
	"github.com/moby/buildkit/frontend/gateway/client"
	"github.com/moby/buildkit/frontend/gateway/grpcclient"
	"github.com/moby/buildkit/util/appcontext"
	"github.com/opencontainers/go-digest"
	"github.com/spf13/cobra"
)

func newFrontendCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "frontend",
		Short: "Frontend entrypoint",
		Args:  cobra.NoArgs,
		RunE:  frontendAction,
	}
	return cmd
}

// mimic dockerfile.v1 frontend
const (
	localNameContext     = "context"
	localNameDockerfile  = "dockerfile"
	keyFilename          = "filename"
	dockerignoreFilename = ".dockerignore"
)

func frontendAction(cmd *cobra.Command, args []string) error {
	nixImage := os.Getenv("NIX_IMAGE")
	if nixImage == "" {
		return fmt.Errorf("missing $NIX_IMAGE")
	}
	return grpcclient.RunFromEnvironment(appcontext.Context(), frontendBuild(nixImage))
}

func frontendBuild(nixImage string) client.BuildFunc {
	return func(ctx context.Context, c client.Client) (*client.Result, error) {
		nixImageSt := llb.Image(nixImage, llb.WithMetaResolver(c), dockerfile2llb.WithInternalName("nix image"))

		dfName := c.BuildOpts().Opts[keyFilename]
		if dfName == "" {
			return nil, fmt.Errorf("option %q was not specified?", keyFilename)
		}
		localDfSt := llb.Local(localNameDockerfile,
			llb.SessionID(c.BuildOpts().SessionID),
			dockerfile2llb.WithInternalName("local dockerfile"),
			llb.FollowPaths([]string{dfName}),
		)

		// Inject the self binary into the ExecOp.
		// Mkfile doesn't work for large files, so we have to mount the self image into the ExecOp.
		selfImageSt, selfImageRefStr, err := getSelfImageSt(ctx, c, localDfSt, dfName)
		if err != nil {
			return nil, err
		}
		selfPath, err := validateSelfImageSt(ctx, c, *selfImageSt, selfImageRefStr)
		if err != nil {
			return nil, err
		}
		localCtxSt, err := getContextSt(ctx, c)
		if err != nil {
			return nil, err
		}

		runSt := nixImageSt.Run(
			llb.AddMount("/context", *localCtxSt),
			llb.AddMount("/dockerfile", localDfSt),
			llb.AddMount("/self", *selfImageSt),
			llb.AddMount("/out", llb.Scratch()),
			llb.AddMount("/cache", llb.Scratch(), llb.AsPersistentCacheDir("todo", llb.CacheMountShared)), // TODO: load cache ID from opt
			llb.Args([]string{filepath.Join("/self", selfPath), "helper", "--filename=" + dfName}),
		)
		def, err := runSt.GetMount("/out").Marshal(ctx, llb.WithCaps(c.BuildOpts().LLBCaps))
		if err != nil {
			return nil, err
		}

		outRes, err := c.Solve(ctx, client.SolveRequest{
			Definition: def.ToPB(),
		})
		if err != nil {
			return nil, err
		}
		outRef, err := outRes.SingleRef()
		if err != nil {
			return nil, err
		}
		config, err := outRef.ReadFile(ctx, client.ReadRequest{Filename: "/.buildkit-nix/config"})
		if err != nil {
			return nil, err
		}
		outRes.AddMeta(exptypes.ExporterImageConfigKey, config)
		return outRes, nil
	}
}

func getSelfImageSt(ctx context.Context, c client.Client, localDfSt llb.State, dfName string) (*llb.State, string, error) {
	localDfDef, err := localDfSt.Marshal(ctx)
	if err != nil {
		return nil, "", err
	}
	localDfRes, err := c.Solve(ctx, client.SolveRequest{
		Definition: localDfDef.ToPB(),
	})
	if err != nil {
		return nil, "", err
	}
	localDfRef, err := localDfRes.SingleRef()
	if err != nil {
		return nil, "", err
	}
	dfBytes, err := localDfRef.ReadFile(ctx, client.ReadRequest{Filename: dfName})
	if err != nil {
		return nil, "", err
	}
	selfImageRefStr, _, _, ok := dockerfile2llb.DetectSyntax(bytes.NewReader(dfBytes))
	if !ok {
		return nil, "", fmt.Errorf("failed to detect self image reference from %q", dfName)
	}
	if selfImageDgst, _, err := c.ResolveImageConfig(ctx, selfImageRefStr, llb.ResolveImageConfigOpt{}); err != nil {
		return nil, "", err
	} else if selfImageDgst != "" {
		selfImageRef, err := reference.ParseNormalizedNamed(selfImageRefStr)
		if err != nil {
			return nil, "", err
		}
		selfImageRefWithDigest, err := reference.WithDigest(selfImageRef, selfImageDgst)
		if err != nil {
			return nil, "", err
		}
		selfImageRefStr = selfImageRefWithDigest.String()
	}
	selfImageSt := llb.Image(selfImageRefStr, llb.WithMetaResolver(c), dockerfile2llb.WithInternalName("self image"))
	return &selfImageSt, selfImageRefStr, nil
}

func validateSelfImageSt(ctx context.Context, c client.Client, selfImageSt llb.State, selfImageRefStr string) (string, error) {
	selfPath, err := os.Executable()
	if err != nil {
		return "", err
	}
	selfR, err := os.Open(selfPath)
	if err != nil {
		return "", err
	}
	selfStat, err := selfR.Stat()
	if err != nil {
		selfR.Close()
		return "", err
	}
	selfSize := selfStat.Size()
	selfDigest, err := digest.Canonical.FromReader(selfR)
	if err != nil {
		selfR.Close()
		return "", err
	}
	if err = selfR.Close(); err != nil {
		return "", err
	}

	def, err := selfImageSt.Marshal(ctx)
	if err != nil {
		return "", err
	}
	res, err := c.Solve(ctx, client.SolveRequest{
		Definition: def.ToPB(),
	})
	if err != nil {
		return "", err
	}
	ref, err := res.SingleRef()
	if err != nil {
		return "", err
	}

	selfStat2, err := ref.StatFile(ctx, client.StatRequest{Path: selfPath})
	if err != nil {
		return "", err
	}
	selfSize2 := selfStat2.Size_
	if int64(selfSize2) != selfSize {
		return "", fmt.Errorf("expected the size of %q in the image %q to be %d, got %d [Hint: set sha256 explicitly in the `# syntax = IMAGE:TAG@sha256:SHA256` line]",
			selfPath, selfImageRefStr, selfSize, selfSize2)
	}

	selfR2, err := refutil.NewRefFileReader(ctx, ref, selfPath)
	if err != nil {
		return "", err
	}
	selfDigest2, err := digest.Canonical.FromReader(selfR2)
	if err != nil {
		return "", err
	}

	if selfDigest2.String() != selfDigest.String() {
		return "", fmt.Errorf("expected the digest of %q in the image %q to be %s, got %s [Hint: set sha256 explicitly in the `# syntax = IMAGE:TAG@sha256:SHA256` line]",
			selfPath, selfImageRefStr, selfDigest, selfDigest2)
	}
	return selfPath, nil
}

func getContextSt(ctx context.Context, c client.Client) (*llb.State, error) {
	st := llb.Local(localNameContext,
		llb.SessionID(c.BuildOpts().SessionID),
		llb.FollowPaths([]string{dockerignoreFilename}),
		dockerfile2llb.WithInternalName("load "+dockerignoreFilename),
		llb.Differ(llb.DiffNone, false),
	)
	def, err := st.Marshal(ctx)
	if err != nil {
		return nil, err
	}
	res, err := c.Solve(ctx, client.SolveRequest{
		Evaluate:   true,
		Definition: def.ToPB(),
	})
	if err != nil {
		return nil, err
	}
	ref, err := res.SingleRef()
	if err != nil {
		return nil, err
	}
	dt, _ := ref.ReadFile(ctx, client.ReadRequest{
		Filename: dockerignoreFilename,
	}) // error ignored

	var excludes []string
	if len(dt) != 0 {
		excludes, err = dockerignore.ReadAll(bytes.NewBuffer(dt))
		if err != nil {
			return nil, err
		}
	}

	st = llb.Local(localNameContext,
		dockerfile2llb.WithInternalName("load build context"),
		llb.SessionID(c.BuildOpts().SessionID),
		llb.ExcludePatterns(excludes),
	)

	return &st, nil
}
