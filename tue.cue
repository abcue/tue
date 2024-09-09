package tue

import (
	"tool/cli"
	"tool/exec"
	"tool/file"

	"github.com/abcue/cup"
)

#Command: cup.PrintRun & {
	// sync resources by generate, init and apply
	"tf-sync": {
		gen: exec.Run & {
			cmd: "cue cmd tf-gen"
		}
		init: exec.Run & {
			$after: gen
			cmd:    "terraform init"
		}
		apply: exec.Run & {
			$after: init
			cmd:    "terraform apply"
		}
		printR: _
	}

	// generate main.tf.json for terraform
	"tf-gen": {
		export: exec.Run & {
			cmd:    "cue export --out=json"
			stdout: string
		}
		jq: exec.Run & {
			cmd:    "jq --sort-keys"
			stdin:  export.stdout
			stdout: string
		}
		save: file.Create & {
			filename: "main.tf.json"
			contents: jq.stdout
		}
		print: cli.Print & {
			text: "Generating main.tf.json"
		}
		printR: _
	}

	// generate all main.tf.json for terraform
	"tf-gen-all": cup.RunPrint & {
		runP: exec.Run & {cmd: ["sh", "-euc", "find . -type d -not -path '*/.terraform*' -mindepth 1 | xargs -I {} sh -euc 'cd {} && cue cmd tf-gen'"]}
	}
}
