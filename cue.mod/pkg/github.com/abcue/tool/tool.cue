package tool

import (
	"strings"
	"tool/cli"
	"tool/exec"
)

RunPrint: {
	// name task as `runP` in `exec.Run` to trigger command print
	runP?: _
	if (runP & exec.Run) != _|_ {
		print: cli.Print & {
			text: *"#!\(runP.cmd)" | _
			if (runP.cmd & string) == _|_ {
				text: *("#!" + strings.Join(runP.cmd, " ")) | _
			}
		}
	}
}
