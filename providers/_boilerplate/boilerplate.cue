// Boilerplate for terraform providers

// replace `provider_name` with the actual provider name
package provider_name

// import "strings"

// replace `product_name` with the actual product name
product_name: {
	#var: {
		name:    string
		product: *"product_name" | _
	}

	let N = #var.name

	// replace `type_name` with the actual resource type
	#provider_name: product_name: type_name: {
		// define `args` for passthrough arguments
		args: {
			// vpc_id:    "${local.rsc_id[\"\(strings.ToLower(vpc.reqs.vpc_name)).vpc\"]}"
			// subnet_id: "${local.rsc_id[\"\(strings.ToLower(vpc.reqs.subnet_name)).subnet\"]}"
		}
		// define `reqs` for user input
		reqs: _
	}

	// create resources with default name
	resource: provider_name_product_name_type_name: (N): {
		#provider_name.product_name.type_name.args
	}

	// create private dns record for resource id lookup
	resource: provider_name_private_dns_record: "\(N)_product_name": {
		zone_id:      "${local.zone_id}"
		sub_domain:   "\(N).product_name"
		ttl:          300
		record_type:  "TXT"
		record_value: "${provider_name_product_name_type_name.\(N).id}"
	}

	// create dependent resources with product suffix to avoid naming conflict
	resource: dep_name: "\(N)_product_name": _
}
