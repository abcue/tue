package rds

import "strings"

#var: {
	name:   "restore"
	region: "us-west-2"
	db_cluster: instance_class: "db.m6gd.2xlarge"
}

_local: {
	db_cluster_identifier:     "humanloop2"
	db_cluster_identifier_ref: "${data.aws_rds_cluster.this.cluster_identifier}"
	attrs: {
		[A=_]:                           _ | *A
		db_cluster_parameter_group_name: _
		...
	}
	args:
		strings.Join([
			for k, v in {
				db_cluster_identifier: #var.name
				snapshot_identifier:   "${aws_db_cluster_snapshot.this.db_cluster_snapshot_arn}"
				engine:                "${aws_db_cluster_snapshot.this.engine}"
				db_subnet_group_name:  "${data.aws_db_subnet_group.this.name}"
				vpc_security_group_ids: strings.Join([
					for sg, _ in data.aws_security_group {
						"${data.aws_security_group.\(sg).id}"
					},
				], " ")
				enable_cloudwatch_logs_exports: "postgresql upgrade"
				db_cluster_instance_class:      #var.db_cluster.instance_class
				region:                         #var.region
				...
			} {
				let a = strings.Replace(k, "_", "-", -1)
				"--\(a) \(v)"
			},
		], " ")

	attrs: {}
}

data: aws_security_group: _

data: aws_rds_cluster: this: cluster_identifier: _local.db_cluster_identifier

resource: aws_db_cluster_snapshot: this: {
	db_cluster_identifier:          _local.db_cluster_identifier_ref
	db_cluster_snapshot_identifier: "\(_local.db_cluster_identifier)-to-restore"
}

import: [{
	id: #var.name
	to: "aws_rds_cluster.this"
}]

resource: aws_rds_cluster: this: {
	deletion_protection:       false
	skip_final_snapshot:       true
	db_cluster_instance_class: "db.m6gd.2xlarge"
	iops:                      24000
	for attr, from in _local.attrs {
		(attr): "${data.aws_rds_cluster.this.\(from)}"
	}
}

// Workaround public accessible setup which is immutable in terraform
output: {
	restore: value: "aws rds restore-db-cluster-from-snapshot \(_local.args) --publicly-accessible --region \(#var.region)"
	wait: value:    "aws rds wait db-cluster-available --db-cluster-identifier \(#var.name) --region \(#var.region)"
	modify: value:  "aws rds modify-db-cluster --db-cluster-identifier \(#var.name) --enable-performance-insights --region \(#var.region)"
	password: {
		value:     "${local.password}"
		sensitive: true
	}
}
