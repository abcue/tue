package aws

ram: {
	#var: {
		name:    string
		product: *"ram" | _
	}

	let N = #var.name

	#aws: ram: {
		resource_share: args: _
		reqs: {
			resource_arn:       _
			resource_share_arn: _
			principal:          _
		}
	}

	resource: aws_ram_resource_share: (N): {
		name: N
		#aws.ram.resource_share.args
	}

	let RSA = "${aws_ram_resource_share.\(N).arn}"

	for i, p in #aws.ram.reqs.principal {
		resource: aws_ram_principal_association: "\(N)_\(i)": {
			principal:          p
			resource_share_arn: RSA
		}
	}

	for i, ra in #aws.ram.reqs.resource_arn {
		resource: aws_ram_resource_association: "\(N)_\(i)": {
			resource_arn:       ra
			resource_share_arn: RSA
		}
	}
}
