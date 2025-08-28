# Python scripts to view Redfish  Power Reading related metrics
Select files from https://github.com/lenovo/python-redfish-lenovo  
From the original github repo Description  
This project includes a set of sample Python scripts that utilize the Redfish API
to manage Lenovo ThinkSystem servers. The scripts use the DMTF python-redfish-library
https://github.com/DMTF/python-redfish-library

For more information on the Redfish API, visit http://redfish.dmtf.org/  
# Usage
$ pip3 install redfish  
$ python get_power_metrics.py -i IPaddr -u user -p password  
[
  {
    "MemberId": "0",
    "Name": "System Power Control",
    "PowerMetrics": {
      "AverageConsumedWatts": 357,
      "IntervalInMin": 1,
      "MaxConsumedWatts": 364,
      "MinConsumedWatts": 354
    }
  }
]  
NOTE: you can also edit CONFIG.INI with Ipaddr and Credentials  

