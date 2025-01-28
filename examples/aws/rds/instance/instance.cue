package rds

#var: {
	name: _
	cloudwatch: dbs: *[name] | _
}

resource: aws_db_instance?: [_]: {
	// Lock version upgrade to prevent uncontrolled changes.
	auto_minor_version_upgrade: false

	// Reasons for not enabling multi az by default
	// * Multi AZ will double the cost
	// * AZ failure is rare in AWS, lower than once per year.
	// * Restoring from snapshot may take up to 1 hour but it still reaches 99.99% SLA yearly
	// * It can be enabled for mission critical instances only.
	// multi_az:                   true

	// Extend retention period to prevent data corruption from application bugs and mal-operation.
	backup_retention_period: 14

	// Prevent instance from deletion by mistake
	deletion_protection: true

	performance_insights_enabled: true
}
