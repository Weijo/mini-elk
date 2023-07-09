# Custom logging tutorial
Original source: https://www.elastic.co/guide/en/elasticsearch/reference/master/ingest.html#pipeline-custom-logs-configuration

TLDR: There are two ways we can set up logging:
1. Using Index templates
2. Directly writing into Custom Configurations in Custom Logs integration

I found method 2 to be very simple

## Setting up the ingest pipeline
1. Go to the ingest pipeline page (Kibana > Management > Stack Management > Ingest Pipelines)
2. Click on Create pipeline > New pipeline
3. Set the name to what you want I did `ctfd.submission`
4. Click on Add a processor
5. Add in your processors
6. Click on Create Pipeline

There are many processors to use. If you are just going for parsing, I recommend using the `grok` processor. The list of patterns can be found here https://github.com/hpcugent/logstash-patterns/blob/master/files/grok-patterns

Below is a sample dataset and the corresponding grok pattern.
```
[06/01/2023 07:50:42] chinaboy submitted b'cool' on 1 with kpm 0 [CORRECT]
```

```
^\[%{DATESTAMP:datestamp}\] %{DATA:user} submitted b'%{DATA:flag}' on %{NUMBER:challengeNo} with kpm %{NUMBER:tries} \[%{DATA:result}\]
```

The format for this is similar to regex. The only extra thing you need to know is the `%{<PATTERN>:<fieldname>}` format. You can define custom patterns too.

I recommend using the Dev tools's Grok Debugger (Kibana > Management > Dev Tools > Grok Debugger) to test your grok patttern.

Below is a sample of my ctfd.submission pipeline
```json
[
  {
    "set": {
      "field": "event.ingested",
      "copy_from": "_ingest.timestamp"
    }
  },
  {
    "grok": {
      "field": "message",
      "patterns": [
        "^\\[%{DATESTAMP:datestamp}\\] %{DATA:user} submitted b'%{DATA:flag}' on %{NUMBER:challengeNo} with kpm %{NUMBER:tries} \\[%{DATA:result}\\]"
      ]
    }
  },
  {
    "set": {
      "field": "event.dataset",
      "value": "ctfd.submission"
    }
  }
]
```

with an failure processor
```json
[
  {
    "set": {
      "field": "error.message",
      "value": "{{ _ingest.on_failure_message }}"
    }
  }
]
```

### Converting datestamp to timestamp format
If you have data that looks like `06/26/2023 10:01:05`

You can convert them into kibana's preferred date timestamp `2023-07-02T14:59:02.224691664Z`
```json
{
  "date": {
    "field": "datestamp",
    "target_field": "log_timestamp",
    "formats": ["MM/dd/yyyy HH:mm:ss"]
  }
},
```

### Doing weird scripting
There's this thing called `painless script` where you can transform the data to add more insights to them.

Some of the things I've done are:
- Dictionary mapping: refer to `ctfd.submissions`
- if else checks for different type of log output: refer to `ctfd.logins`


## Creating Custom Integration
1. Go to fleet > agent policy > select a policy > add integration > select Custom Logs > add custom logs
2. Write your integration name
3. Select the log file path
4. Set dataset name
4. Click on Advanced Options > Under Custom configurations add the following:
```json
pipeline: <your pipeline name>
```

Once that is done, you should see your logs being parsed.

I'm not sure if you can set multiple pipelines at once. Its safer to spam a bunch of custom log integrations with their own separate pipelines.

## Custom log list

```
name: ctfd-submissions
logpath: /home/ctfd/CTFd/.data/CTFd/logs/submissions.log
pipeline: ctfd.submissions

name: ctfd-logins
logpath: /home/ctfd/CTFd/.data/CTFd/logs/logins.log
pipeline: ctfd.logins

name: ctfd-registrations
logpath: /home/ctfd/CTFd/.data/CTFd/logs/registrations.log
pipeline: ctfd.registrations

Apache
logpath: /home/ctfd/CTFd/.data/CTFd/logs/access.log*
logpath: /home/ctfd/CTFd/.data/CTFd/logs/error.log*
```