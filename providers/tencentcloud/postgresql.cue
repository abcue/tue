package tencentcloud

import (
	"encoding/json"
	"strings"
)

postgresql: {
	#var: {
		product: *"postgresql" | _
		name:    string
	}

	#tencentcloud: {
		vpc: reqs: {
			vpc_name:          string
			subnet_name:       string
			availability_zone: string
		}
		private_dns: reqs: domain: string
		postgresql: {
			instance: args: {
				root_user: *"root" | string
				vpc_id:    "${local.rsc_id[\"\(strings.ToLower(vpc.reqs.vpc_name)).vpc\"]}"
				subnet_id: "${local.rsc_id[\"\(strings.ToLower(vpc.reqs.subnet_name)).subnet\"]}"
			}
			readonly_instance?: args: _
		}

		vault?: kv_secret_v2?: args?: {
			mount: _
			name:  _
		}
	}

	let N = #var.name

	resource: tencentcloud_postgresql_instance: (N): {
		#tencentcloud.postgresql.instance.args
		name:              N
		root_password:     "${random_password.\(N)_postgresql.result}"
		storage:           *20 | _
		memory:            *2 | _
		availability_zone: *#tencentcloud.vpc.reqs.availability_zone | _
		db_major_version:  *"17" | _
		charge_type:       *"PREPAID" | _
		if charge_type == "PREPAID" {
			auto_renew_flag: *1 | _
		}
		delete_protection: true
	}

	resource: random_password: "\(N)_postgresql": {
		length:           16
		min_lower:        1
		min_numeric:      1
		min_special:      1
		min_upper:        1
		override_special: "/"
	}

	let PD = "pg.\(#tencentcloud.private_dns.reqs.domain)"
	let PZ = #"${local.rsc_id["\#(PD).dns_zone"]}"#
	let PI = "tencentcloud_postgresql_instance.\(N)"

	resource: tencentcloud_private_dns_record: (N + "_A"): {
		zone_id:      PZ
		sub_domain:   "${\(PI).id}"
		record_type:  "A"
		record_value: "${\(PI).private_access_ip}"
		ttl:          300
	}

	resource: tencentcloud_private_dns_record: (N + "_CNAME"): {
		zone_id:      PZ
		sub_domain:   N
		record_type:  "CNAME"
		record_value: "${\(PI).id}.\(PD)"
		ttl:          300
	}

	let RO_ARGS = {
		name:                  N + "-ro"
		master_db_instance_id: "${\(PI).id}"
		for arg, from in {
			[arg=_]:               *arg | _
			"security_groups_ids": "security_groups"
			"vpc_id":              _
			"subnet_id":           _
			"project_id":          _
		} {
			(arg): "${\(PI).\(from)}"
		}
	}

	if #tencentcloud.postgresql.readonly_instance.args != _|_ {
		resource: tencentcloud_postgresql_readonly_group: (N): {
			RO_ARGS
			max_replay_lag:              0
			max_replay_latency:          0
			min_delay_eliminate_reserve: 0
			replay_lag_eliminate:        0
			replay_latency_eliminate:    0
		}

		resource: tencentcloud_postgresql_readonly_instance: (N): {
			RO_ARGS
			#tencentcloud.postgresql.readonly_instance.args
			zone:               "${\(PI).availability_zone}"
			read_only_group_id: "${tencentcloud_postgresql_readonly_group.\(N).id}"
			for arg, from in {
				[arg=_]:      *arg | _
				"db_version": "engine_version"
				"memory":     _
				"storage":    _
			} {
				(arg): *"${\(PI).\(from)}" | _
			}
		}

		let RG = "${tencentcloud_postgresql_readonly_group.\(N).id}"

		resource: tencentcloud_private_dns_record: (N + "_ro_A"): {
			zone_id:      PZ
			sub_domain:   RG
			record_type:  "A"
			record_value: "${\(PI).private_access_ip}"
			ttl:          300
		}

		resource: tencentcloud_private_dns_record: (N + "_ro_CNAME"): {
			zone_id:      PZ
			sub_domain:   N + "-ro"
			record_type:  "CNAME"
			record_value: "\(RG).\(PD)"
			ttl:          300
		}
	}

	if #tencentcloud.vault.kv_secret_v2.args != _|_ {
		resource: vault_kv_secret_v2: (N + "_postgresql"): {
			#tencentcloud.vault.kv_secret_v2.args
			data_json: json.Marshal({
				username: "${\(PI).root_user}"
				password: "${\(PI).root_password}"
			})
		}
	}

	output: postgresql: value: {
		conn:     "postgresql://${\(PI).root_user}@${tencentcloud_private_dns_record.\(N)_CNAME.sub_domain}.\(PD):${\(PI).private_access_port}"
		migrate?: """
			terraform state mv random_password.this random_password.\(N)_postgresql
			terraform state mv tencentcloud_postgresql_instance.this \(PI)
			terraform state mv tencentcloud_private_dns_record.this tencentcloud_private_dns_record.\(N)_A
			terraform state mv tencentcloud_private_dns_record.this tencentcloud_private_dns_record.\(N)_CNAME
			terraform state mv vault_kv_secret_v2.this vault_kv_secret_v2.\(N)_postgresql
			"""
	}
}
