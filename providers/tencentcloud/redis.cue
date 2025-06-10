package tencentcloud

redis: {
	#var: {
		name: string
		args: {
			vpc_name:          string
			subnet_name:       string
			availability_zone: string
		}
		redis: instance: {...}
	}

	let N = #var.name

	resource: tencentcloud_redis_instance: (N): #var.redis.instance & {
		name:              N
		vpc_id:            "${local.vpc_id}"
		subnet_id:         "${local.subnet_id}"
		availability_zone: *#var.args.availability_zone | _
		mem_size:          *1024 | _
		// Instance type.
		// 2: Redis 2.8 Memory Edition (standard architecture);
		// 3: CKV 3.2 Memory Edition (standard architecture);
		// 4: CKV 3.2 Memory Edition (cluster architecture);
		// 6: Redis 4.0 Memory Edition (standard architecture);
		// 7: Redis 4.0 Memory Edition (cluster architecture);
		// 8: Redis 5.0 Memory Edition (standard architecture);
		// 9: Redis 5.0 Memory Edition (cluster architecture);
		// 15: Redis 6.2 Memory Edition (standard architecture);
		// 16: Redis 6.2 Memory Edition (cluster architecture);
		// 17: Redis 7.0 Memory Edition (standard architecture);
		// 18: Redis 7.0 Memory Edition (cluster architecture).
		type_id:  *17 | _
		password: "${random_password.\(N).result}"
	}

	resource: random_password: (N): {
		length:           16
		min_lower:        1
		min_numeric:      1
		min_special:      1
		override_special: "_"
	}
	output: {
		password: {
			sensitive: true
			value:     "${tencentcloud_redis_instance.\(N).password}"
		}
	}
}
