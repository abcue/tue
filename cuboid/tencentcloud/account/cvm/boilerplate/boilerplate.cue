package account

import "github.com/abcue/tue/providers/tencentcloud"

#var: name: "boilerplate"

#tencentcloud: {
	instance: {
		reqs: {
			cpu:    1
			memory: 2
			disk:   10
		}
		// Set arguments of [tencentcloud_instance](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/instance)
		args: image_id: "img-m07ny34j"
	}
	// Set security group
	security_group: reqs: ingress: {
		// Simple rules
		ssh: {
			args: {
				protocol:    "TCP"
				port:        "22"
				description: "ssh"
			}
			reqs: ipm: ["ipm1", "ipm2"]
		}
		all: {
			args: {
				protocol:    "ALL"
				port:        "ALL"
				description: "All traffic"
			}
			reqs: ipm: ["ipm1", "ipm2"]
		}
		// Set TCP rules by port
		for _port, _desc in {
			"22":   "ssh"
			"3389": "Remote Desktop Protocol"
		} {
			(_port): {
				// Set arguments of [tencentcloud_security_group_rule_set](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/security_group_rule_set)
				args: description: _desc
				// Lookup address template in rsc_id and convert to `address_template_id`
				reqs: ipm: ["ipm1"]
			}
		}

		// Set rules by protocol and port
		for _protocol in ["TCP", "UDP"] for _port, _desc in {
			"67": "dhcp"
			"68": "dhcp"
			"69": "tftp"
		} {
			("\(_protocol)_\(_port)"): {
				args: {
					protocol:    _protocol
					port:        _port
					description: _desc
				}
				reqs: ipm: ["ipm1", "ipm2"]
			}
		}
	}
}

tencentcloud.cvm
