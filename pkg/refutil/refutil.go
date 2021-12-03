package refutil

import (
	"context"
	"fmt"
	"io"

	"github.com/moby/buildkit/frontend/gateway/client"
)

func NewRefFileReader(ctx context.Context, ref client.Reference, fp string) (io.Reader, error) {
	stat, err := ref.StatFile(ctx, client.StatRequest{Path: fp})
	if err != nil {
		return nil, err
	}
	r := &refFileReader{
		ctx:     ctx,
		ref:     ref,
		path:    fp,
		sz:      stat.Size_,
		offset:  0,
		bufSize: 1024 * 64,
	}
	return r, nil
}

type refFileReader struct {
	ctx     context.Context
	ref     client.Reference
	path    string
	sz      int64
	offset  int64
	bufSize int
}

func (r *refFileReader) Read(p []byte) (int, error) {
	if r.offset >= r.sz {
		return 0, io.EOF
	}
	bufSize := len(p)
	if bufSize > r.bufSize {
		bufSize = r.bufSize
	}
	req := client.ReadRequest{
		Filename: r.path,
		Range: &client.FileRange{
			Offset: int(r.offset),
			Length: bufSize,
		},
	}
	b, err := r.ref.ReadFile(r.ctx, req)
	r.offset += int64(len(b))
	if n := copy(p, b); n != len(b) {
		return len(b), fmt.Errorf("failed to copy: n != len(b) [n=%d, len(b)=%d]", n, len(b))
	}
	if err != nil {
		return len(b), err
	}
	return len(b), nil
}
