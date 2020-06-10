# infrastructure
code for infrastructure setup in AWS
----------------------------------------------------
Steps to create network setup:
$terraform init
$terraform plan (give vpc_cidr as 172.16.0.0/16 and public_destination_route_cidr as 0.0.0.0/0)
$terraform apply
-----------------------------------------------------
Steps to delete the created network setup :
$terraform plan -destroy
$terraform destroy
-----------------------------------------------------
To get the list of created resources: 
$terraform show list
-----------------------------------------------------
To update the local state file with real remote resource state:
$terraform refresh