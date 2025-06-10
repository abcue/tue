package aws

import "strings"

db: {
	#var: name: string

	let N = #var.name

	#aws: db: {
		instance: args: _
		restore?: {
			reqs: copy_args: {
				[to=_]:                 *to | _
				db_subnet_group_name:   "db_subnet_group"
				instance_class:         "db_instance_class"
				publicly_accessible:    _
				username:               "master_username"
				vpc_security_group_ids: "vpc_security_groups"
			}
			args: db_instance_identifier: *strings.TrimSuffix(#var.name, "-restore") | _
		}
		replicate?: reqs: copy_args: {
			[to=_]:                *to | _
			allocated_storage:     _
			engine:                _
			instance_class:        _
			max_allocated_storage: _
			storage_encrypted:     _
		}
	}

	resource: aws_db_instance: (N): {
		#aws.db.instance.args
		identifier: *N | _
		...
	}

	if #aws.db.replicate != _|_ {
		let RO = N + "-ro"
		resource: aws_db_instance: (RO): {
			identifier:          *RO | _
			instance_class:      *"${aws_db_instance.\(N).instance_class}" | _
			replicate_source_db: "${aws_db_instance.\(N).identifier}"
			for dst, src in #aws.db.replicate.reqs.copy_args {
				(dst): *"${aws_db_instance.\(N).\(src)}" | _
			}
		}
	}

	if #aws.db.restore != _|_ {
		let RN = #aws.db.restore.args.db_instance_identifier
		data: aws_db_instance: (RN): #aws.db.restore.args
		data: aws_db_snapshot: (RN): {
			#aws.db.restore.args
			most_recent: true
		}
		resource: aws_db_instance: (N): {
			snapshot_identifier: "${data.aws_db_snapshot.\(RN).db_snapshot_arn}"
			for dst, src in #aws.db.restore.reqs.copy_args {
				(dst): *"${data.aws_db_instance.\(RN).\(src)}" | _
			}
		}
	}
}
