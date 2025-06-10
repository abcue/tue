package tencentcloud

project: {
	#var: {
		name:    string
		product: *"project" | _
	}

	#tencentcloud: project: reqs: _

	for k, v in #tencentcloud.project.reqs {
		resource: tencentcloud_project: (k): {
			project_name: k
			info:         v
		}

		resource: tencentcloud_private_dns_record: "\(k)_project": {
			zone_id:      "${local.zone_id}"
			sub_domain:   "\(k).project"
			ttl:          300
			record_type:  "TXT"
			record_value: "${tencentcloud_project.\(k).id}"
		}
	}

}
