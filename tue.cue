package tue

import (
	"tool/exec"

	"github.com/abcue/tool"
)

#Command: {
	[_]: tool.RunPrint
	// sync resources by generate, init and apply
	"tf-sync": {
		runP: exec.Run & {cmd: ["sh", "-c", "cue cmd tf-gen && terraform init && terraform apply"]}
	}

	// generate main.tf.json for terraform
	"tf-gen": {
		runP: exec.Run & {cmd: ["sh", "-c", "cue export --out=json | jq --sort-keys > main.tf.json"]}
	}

	// generate all main.tf.json for terraform
	"tf-gen-all": {
		runP: exec.Run & {cmd: ["sh", "-c", "find . -type d -not -path '*/.terraform*' -mindepth 1 | xargs -I {} sh -c 'cd {} && cue cmd tf-gen'"]}
	}
}
