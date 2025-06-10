package tencentcloud

key_pair: {
	#var: name: string

	#tencentcloud: key_pair: reqs: [name=_]: _ // public key

	for name, key in #tencentcloud.key_pair.reqs {
		let KN = "\(name)_\(#var.name)"
		resource: tencentcloud_key_pair: (KN): {
			key_name:   KN
			public_key: key
		}

		resource: tencentcloud_private_dns_record: "\(KN)_key_pair": {
			zone_id:      "${local.rsc_id_zone_id}"
			sub_domain:   "\(KN).key_pair"
			ttl:          300
			record_type:  "TXT"
			record_value: "${tencentcloud_key_pair.\(KN).id}"
		}
	}
}
