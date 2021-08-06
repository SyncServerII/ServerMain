#!/bin/bash

# This is adapted from https://stackoverflow.com/questions/28060845/aws-cloudwatch-log-is-it-possible-to-export-existing-log-data-from-it

# First, you need to go to AWS to get the specifics for log group and stream name
# I.e., For the Neebla server, go to: https://us-west-2.console.aws.amazon.com/cloudwatch/home?region=us-west-2#logsV2:log-groups/log-group/$252Faws$252Felasticbeanstalk$252Fneebla-02-production$252Fhome$252Fec2-user$252Foutput.log

# Here is an example command line:

aws logs get-log-events \
    --log-group-name /aws/elasticbeanstalk/neebla-02-production/home/ec2-user/output.log\
    --log-stream-name neebla-02-production--i-042d0c6048b84ea46 > output.aws.log.txt

