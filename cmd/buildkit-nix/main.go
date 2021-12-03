package main

import (
	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

func main() {
	cmd := &cobra.Command{
		Use:           "buildkit-nix",
		Short:         "DO NOT EXECUTE THIS BINARY MANUALLY",
		SilenceErrors: true,
		SilenceUsage:  true,
	}
	cmd.AddCommand(newFrontendCmd(), newHelperCmd())
	if err := cmd.Execute(); err != nil {
		logrus.Fatal(err)
	}
}
