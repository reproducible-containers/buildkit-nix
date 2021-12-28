package main

import (
	"compress/gzip"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/containerd/containerd/archive"
	"github.com/containerd/containerd/content"
	"github.com/containerd/containerd/content/local"
	"github.com/containerd/containerd/images"
	imagesarchive "github.com/containerd/containerd/images/archive"
	securejoin "github.com/cyphar/filepath-securejoin"
	"github.com/opencontainers/go-digest"
	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

func newHelperCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "helper",
		Short: "Helper command, executed inside the Nix container",
		Args:  cobra.NoArgs,
		RunE:  helperAction,
	}
	cmd.Flags().String("filename", "", "corresponds to keyFilename")
	return cmd
}

// copyDirOverwrite is similar to continuity/fs.CopyDir but allows overwriting existing files
func copyDirOverwrite(dst, src string) error {
	cmd := exec.Command("cp", "-afT", src, dst)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("failed to run %v: %w (out=%q)", cmd.Args, err, out)
	}
	return nil
}

func helperAction(cmd *cobra.Command, args []string) error {
	ctx := cmd.Context()
	logrus.Info("Populating cache from /cache into /nix")
	// because BuildKit mounts do not support automatic copy-up
	if err := copyDirOverwrite("/nix", "/cache"); err != nil {
		return err
	}
	filename, err := cmd.Flags().GetString("filename")
	if err != nil {
		return err
	}
	if filename == "" {
		return fmt.Errorf("missing --filename flag")
	}
	fullFilename, err := securejoin.SecureJoin("/dockerfile", filename)
	if err != nil {
		return err
	}
	flakeMode := filepath.Base(filename) == "flake.nix"
	// nix creates a docker V1 tgz to /context/result .
	var nixBuildCmd *exec.Cmd
	if flakeMode {
		nixBuildCmd = exec.CommandContext(ctx,
			"nix",
			"--extra-experimental-features", "nix-command",
			"--extra-experimental-features", "flakes",
			"build",
			"--option", "build-users-group", "",
			"/dockerfile",
		)
	} else {
		nixBuildCmd = exec.CommandContext(ctx, "nix-build", "--option", "build-users-group", "", fullFilename)
	}
	nixBuildCmd.Dir = "/context"
	nixBuildCmd.Stderr = cmd.OutOrStderr()
	nixBuildCmd.Stdout = nixBuildCmd.Stderr
	logrus.Infof("Running %v (flake mode: %v)", nixBuildCmd.Args, flakeMode)
	if err := nixBuildCmd.Run(); err != nil {
		return err
	}
	dockerV1TgzR, err := os.Open("/context/result")
	if err != nil {
		return err
	}
	defer dockerV1TgzR.Close()
	dockerV1TarR, err := gzip.NewReader(dockerV1TgzR)
	if err != nil {
		return err
	}
	csDir, err := os.MkdirTemp("", "buildkit-nix-cs")
	if err != nil {
		return err
	}
	defer os.RemoveAll(csDir)
	cs, err := local.NewStore(csDir)
	if err != nil {
		return err
	}
	logrus.Info("Importing the result file to CS")
	dockerV1TarDigester := digest.SHA256.Digester()
	dockerV1TarHasher := dockerV1TarDigester.Hash()
	dockerV1TarTee := io.TeeReader(dockerV1TarR, dockerV1TarHasher)
	idx, err := imagesarchive.ImportIndex(ctx, cs, dockerV1TarTee)
	if err != nil {
		return err
	}
	if _, err := io.Copy(io.Discard, dockerV1TarTee); err != nil {
		return err
	}
	dockerV1TarDigest := dockerV1TarDigester.Digest()
	logrus.Infof("Gunzippped digest: %s", dockerV1TarDigest)
	logrus.Infof("Index: %+v", idx)

	mani, err := images.Manifest(ctx, cs, idx, nil)
	if err != nil {
		return fmt.Errorf("failed to get the image manifest from index %+v: %w", idx, err)
	}
	logrus.Infof("Manifest: %+v", mani)
	if len(mani.Layers) == 0 {
		return errors.New("no layer was built?")
	}
	for i, layer := range mani.Layers {
		logrus.Infof("Extracting the layer %d/%d (%s) to /out", i+1, len(mani.Layers), layer.Digest)
		layerReaderAt, err := cs.ReaderAt(ctx, layer)
		if err != nil {
			return err
		}
		layerReader := content.NewReader(layerReaderAt)
		if _, err := archive.Apply(ctx, "/out", layerReader); err != nil {
			layerReaderAt.Close()
			return err
		}
		if err := layerReaderAt.Close(); err != nil {
			return err
		}
	}

	logrus.Infof("Writing the gunzipped digest (%s) to /out/.buildkit-nix/result.gunzipped.digest", dockerV1TarDigest)
	if err := os.MkdirAll("/out/.buildkit-nix", 0755); err != nil {
		return err
	}
	if err := os.WriteFile("/out/.buildkit-nix/result.gunzipped.digest", []byte(dockerV1TarDigest.String()+"\n"), 0644); err != nil {
		return err
	}

	logrus.Infof("Extracting the config (%s) to /out/.buildkit-nix/config", mani.Config.Digest)
	configBlob, err := content.ReadBlob(ctx, cs, mani.Config)
	if err != nil {
		return err
	}
	if err := os.WriteFile("/out/.buildkit-nix/config", configBlob, 0644); err != nil {
		return err
	}

	logrus.Info("Finalizing")
	if err := resetTimestamp("/out/.buildkit-nix", time.Unix(0, 0)); err != nil {
		return err
	}

	logrus.Info("Populating back cache from /nix into /cache")
	// because BuildKit mounts do not support automatic copy-up
	_ = os.RemoveAll("/cache")
	if err := copyDirOverwrite("/cache", "/nix"); err != nil {
		return err
	}

	return nil
}

func resetTimestamp(p string, t time.Time) error {
	walk := func(joined string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if err := os.Chtimes(joined, t, t); err != nil {
			return err
		}
		return nil
	}
	return filepath.Walk(p, walk)
}
