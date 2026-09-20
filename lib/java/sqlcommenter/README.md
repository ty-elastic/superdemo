# sqlcommenter-otel

When results are examined in SQL database logs, they'll look like this:

```shell
SELECT * from USERS /*action='run+this+%26+that',
controller='foo%3BDROP+TABLE+BAR',framework='spring,
traceparent='00-9a4589fe88dd0fc911ff2233ffee7899-11fa8b00dd11eeff-01',
tracestate='rojo%253D00f067aa0ba902b7%2Ccongo%253Dt61rcWkgMzE''*/
```

## Install

### JVM

"-Dloader.path=/usr/src/app/lib"

### application.properties

spring.jpa.properties.hibernate.session_factory.statement_inspector=com.example.sqlcommenter.Inspector


