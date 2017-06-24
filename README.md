
Creates a stable EC2 hostname using EC2 host discovery

This is based on the wonderful `cap-ec2` gem...
https://github.com/forward3d/cap-ec2

Customize it for your environment and then add it to your server build (e.g. Cloudformation).

`gem install bundler`
`bundle install`
`AWS_ACCESS_KEY_ID=x AWS_SECRET_ACCESS_KEY=y ruby dns_name.rb production Worker worker your-domain.com`

This will create the name `production-Worker-1.your-domain.com` based on a looking of specific `Role`, `Project` and `Stage` tags.

You should have a `Name` tag such as `production-Worker-1` or `production-App-1`.

You will need a IAM policy to allow host discovery for your IAM user (minimum `ec2:DescribeInstances`, `ec2:DescribeTags`):

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1498026418000",
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
```

Hopefully the next version of this will have the ability to update the name of the EC2 instance too.