package product

postgresql: {
	#var: {
		name: string
		args: {
			vpc_name:          string
			subnet_name:       string
			domain:            string
			availability_zone: string
		}
		private_dns: domain: string
		postgresql: {
			dns_zone: *("pg." + #var.private_dns.domain) | _
			instance: {
				root_user: *"root" | string
				...
			}
		}
	}

	let N = #var.name

	resource: tencentcloud_postgresql_instance: (N): #var.postgresql.instance & {
		name:              N
		root_password:     "${random_password.\(N).result}"
		vpc_id:            "${local.vpc_id}"
		storage:           *20 | _
		memory:            *2 | _
		availability_zone: *#var.args.availability_zone | _
		subnet_id:         "${local.subnet_id}"
		db_major_version:  *"17" | _
		charge_type:       *"PREPAID" | _
		if charge_type == "PREPAID" {
			auto_renew_flag: *1 | _
		}
		delete_protection: true
	}

	resource: random_password: (N): {
		length:           16
		min_lower:        1
		min_numeric:      1
		min_special:      1
		min_upper:        1
		override_special: "/"
	}

	resource: tencentcloud_private_dns_record: (N): {
		zone_id:      "${local.rsc_id[\"\(#var.postgresql.dns_zone).dns_zone\"]}"
		record_type:  "A"
		record_value: "${tencentcloud_postgresql_instance.\(N).private_access_ip}"
		sub_domain:   N
		ttl:          300
	}

	locals: host: "${resource.tencentcloud_private_dns_record.\(N).sub_domain}.\(#var.postgresql.dns_zone)"

	output: {
		conn: value: "postgresql://\(#var.postgresql.instance.root_user)@${local.host}"
		psql: value: "psql --host ${local.host} --username \(#var.postgresql.instance.root_user) --dbname postgres"
		root_password: {
			sensitive: true
			value:     "${tencentcloud_postgresql_instance.\(N).root_password}"
		}
	}
}
