package rds

import "strings"

provider: aws: region: "us-west-2"

#var: {
	name:           _
	engine:         *"postgres" | _
	engine_version: *16 | _
	cloudwatch: {
		alarms: {} | *{
			"FreeStorageSpace": "LessThanThreshold":           _
			"CPUUtilization": "GreaterThanOrEqualToThreshold": int | *60
			"DatabaseConnections": {
				"GreaterThanOrEqualToThreshold": int | *40
				"LessThanOrEqualToThreshold":    int | *-1
			}
			"WriteLatency": "GreaterThanOrEqualToThreshold": number | *0.2
			"ReadLatency": "GreaterThanOrEqualToThreshold":  number | *0.01
		}
		actions: *["arn:aws:sns:us-west-2:726920260722:\(name)-alarms"] | _
		dbs: *[
			"\(name)-instance-1",
			"\(name)-instance-2",
			"\(name)-instance-3",
		] | _
	}
	instances: *{} | _
	restore?: {
		cluster?:  *strings.TrimSufix(name, "-restore") | _
		instance?: *name | _
	}
}

_local: {
	family:                          *"\(#var.engine)\(#var.engine_version)" | _
	snapshot_identifier:             *"${aws_db_snapshot.this.db_snapshot_arn}" | _
	db_cluster_parameter_group_name: *"debezium-\(family)" | _
	if resource.aws_rds_cluster_parameter_group.debezium != _|_ {
		db_cluster_parameter_group_name: "${aws_rds_cluster_parameter_group.debezium.name}"
	}
	attrs: _
	attr_map: {
		[A=_]:                           _ | *A
		backup_retention_period:         _
		db_cluster_parameter_group_name: _
		db_subnet_group_name:            _
		engine_version:                  _
		master_username:                 _
		preferred_backup_window:         _
		preferred_maintenance_window:    _
		...
	}
}

if #var.restore.cluster != _|_ {
	data: aws_rds_cluster: this: {
		cluster_identifier: #var.restore.cluster
	}

	resource: aws_db_cluster_snapshot: this: {
		db_cluster_identifier:          "${data.aws_rds_cluster.this.cluster_identifier}"
		db_cluster_snapshot_identifier: "\(#var.name)"
	}

	_local: {
		attr_map: _
		attrs: {for attr, from in attr_map {
			(attr): *"${data.aws_rds_cluster.this.\(from)}" | _
		}}
		snapshot_identifier: "${aws_db_cluster_snapshot.this.db_cluster_snapshot_arn}"
	}
}

if #var.restore.instance != _|_ {
	data: aws_db_instance: this: {
		db_instance_identifier: #var.restore.instance
	}
	resource: aws_db_snapshot: this: {
		db_instance_identifier: "${data.aws_db_instance.this.db_instance_identifier}"
		db_snapshot_identifier: #"\#(#var.name)-${replace(timestamp(),":","-")}"#
		lifecycle: ignore_changes: ["db_snapshot_identifier"]
	}

	_local: {
		attr_map: database_name: "db_name"
		attrs: {for attr, from in attr_map {
			(attr): *"${data.aws_db_instance.this.\(from)}" | _
		}}
	}
}

data: aws_security_group: _

resource: aws_rds_cluster?: this: {
	_local.attrs

	cluster_identifier: #var.name
	engine:             #var.engine
	master_password:    "${local.password}"

	if #var.restore != _|_ {
		snapshot_identifier: _local.snapshot_identifier
	}

	if #var.restore == _|_ {
		db_cluster_parameter_group_name: _local.db_cluster_parameter_group_name
	}

	vpc_security_group_ids: [
		for sg, _ in data.aws_security_group {
			"${data.aws_security_group.\(sg).id}"
		},
	]

	if strings.HasPrefix(engine, "aurora-") {
		serverlessv2_scaling_configuration: [{
			max_capacity: 128.0
			min_capacity: 1.0
		}]
	}

	deletion_protection: *true | false
	enabled_cloudwatch_logs_exports: [
		"postgresql",
		"upgrade",
	]
}

resource: aws_rds_cluster_parameter_group?: debezium: {
	name:   _local.db_cluster_parameter_group_name
	family: _local.family
	parameter: [{
		apply_method: "pending-reboot"
		name:         "rds.logical_replication"
		value:        "1"
	}]
}

for i, _ in #var.instances {
	resource: aws_rds_cluster_instance: (i): {
		identifier:                   "\(#var.name)-\(i)"
		cluster_identifier:           "${aws_rds_cluster.this.id}"
		engine:                       "${aws_rds_cluster.this.engine}"
		performance_insights_enabled: true
		publicly_accessible:          true
		instance_class:               "db.serverless"
		auto_minor_version_upgrade:   false
	}
}

resource: aws_cloudwatch_metric_alarm?: {
	[_]: {
		namespace:                 "AWS/RDS"
		alarm_actions:             #var.cloudwatch.actions
		ok_actions:                #var.cloudwatch.actions
		insufficient_data_actions: #var.cloudwatch.actions
		period:                    600
		evaluation_periods:        int | *1
		statistic:                 "Average"
		dimensions: DBInstanceIdentifier: _

		metric_name:         string
		comparison_operator: string
		threshold:           _

		alarm_name:        string | *"\(dimensions.DBInstanceIdentifier)_\(metric_name)_\(comparison_operator)"
		alarm_description: string | *"\(dimensions.DBInstanceIdentifier) \(metric_name) \(comparison_operator) \(threshold) within last \(period)s"
	}
	for metric, alarm in #var.cloudwatch.alarms {
		for comp, thres in alarm {
			for db in #var.cloudwatch.dbs {
				"\(db)_\(metric)_\(comp)": {
					metric_name:         metric
					comparison_operator: comp
					threshold:           thres
					dimensions: DBInstanceIdentifier: db
				}
			}
		}
	}
}

output: cluster: value: {
	for attr in ["endpoint", "reader_endpoint"] {
		(attr): "${aws_rds_cluster.this.\(attr)}"
	}
}
