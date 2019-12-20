# ES+Kafka+logstash+FileBeat统一收集SpringCloud项目日志并使用Kibana监控
```text
整体思路：
所有SpringCloud 微服务docker挂载日志到本机/var/datainsights-logs，FileBeat也挂载本机目录/var/datainsights-logs并收集/var/datainsights-logs
目录下到所有日志，然后把日志发送到kafka，使用kafka可以多次消费日志。日志推送到es之外还有Error日志必须告警给开发人员。logstash监听Kafka并把日志推送到es
之中
```
### 进入elasticsearch-kibana-7.1.1执行如下命令启动elasticsearch，kibana
```shell script
docker-compose -f docker-compose-single-node.yml up -d
```
## 新建

### 进入elasticsearch-logstash-7.1.1执行如下命令启动logstash，filebeat
```shell script
docker-compose -f docker-compose-prod.yml up -d
```

### 浏览器输入127.0.0.1：5601 在console 页面之中新建SpringCloud 日志索引生命周期，每1000条日志记录rollover，时长1天为warm，7天就删除
```json
PUT _ilm/policy/microservice_log_ilm_policy
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_docs": "1000"
          }
        }
      },
      "warm": {
        "min_age": "1d",
        "actions": {
          "readonly" : {}
        }
      },
      "cold":{
        "min_age": "3d",
        "actions": {
          "freeze" : {}
        }
      },
      "delete": {
        "min_age": "7d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
```
### SpringCloud 日志索引模板设置生命周期
```json
PUT _template/spring_cloud_log_template
{
  "index_patterns": [
    "spring-cloud-*"
  ],
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 1,
    "index.lifecycle.name": "microservice_log_ilm_policy"，
    "index.lifecycle.rollover_alias": "microservice_log"
  },
  "mappings": {
    "_source": {
      "enabled": true
    },
    "properties": {
      "server_name": {
        "type": "keyword"
      },
      "log_level": {
        "type": "keyword"
      },
      "ip": {
        "type": "keyword"
      },
      "logger": {
        "type": "keyword"
      },
      "thread": {
        "type": "keyword"
      },
      "class": {
        "type": "keyword"
      },
      "log_info": {
        "type": "text",
        "analyzer": "ik_max_word",
        "search_analyzer": "ik_smart"
      },
      "agent": {
        "properties": {
          "ephemeral_id": {
            "type": "keyword"
          },
          "hostname": {
            "type": "keyword"
          },
          "id": {
            "type": "keyword"
          },
          "type": {
            "type": "keyword"
          },
          "version": {
            "type": "keyword"
          }
        }
      },
      "timestamp": {
        "type": "date",
        "format": "yyyy-MM-dd HH:mm:ss||yyyy-MM-dd||epoch_millis||yyyy-MM-dd'T'HH:mm:ss||yyyy-MM-dd'T'HH:mm:ss.SSSZ||yyyy-MM-dd HH:mm:ss.SSS||yyyy-MM-dd HH:mm:ss.SSSZ"
      }
    }
  }
}
```

```text
SpringCloud 日志配置文件logback-spring.xml，放在SpringCloud resources目录下，配置的spring.log.dir必须和filebeat收集路径一致
```
```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration debug="false" scan="false">
	<springProperty scope="context" name="server_name" source="spring.application.name"/>
    <!--   spring.log.dir为环境变量配置可以使用Docker环境变量配置 -->
	<springProperty scope="context" name="log_dir" source="spring.log.dir" defaultValue="/var/datainsights-logs"/>
	<!--	统一日志存储路径，ELK FileBeat统一收集日志-->
	<property name="log.path" value="${log_dir}/${server_name}"/>
	<!-- 彩色日志格式 -->
	<property name="CONSOLE_LOG_PATTERN"
			  value="${CONSOLE_LOG_PATTERN:-%clr(%d{yyyy-MM-dd HH:mm:ss.SSS}){faint} %clr(%-5level) %clr(%host) %clr(${PID:-}){magenta} %clr(%class{26}#%method) %X{req.remoteHost} %X{req.requestURL} %m ${LOG_EXCEPTION_CONVERSION_WORD:-%wex}}%n"/>
	<!-- 彩色日志依赖的渲染类 -->
	<conversionRule conversionWord="clr" converterClass="org.springframework.boot.logging.logback.ColorConverter"/>
	<conversionRule conversionWord="host" converterClass="biz.datainsights.common.core.log.LogIpConverter"/>
	<conversionRule conversionWord="wex"
					converterClass="biz.datainsights.common.core.log.XWhitespaceThrowableProxyConverter"/>
	<conversionRule conversionWord="wEx"
					converterClass="org.springframework.boot.logging.logback.ExtendedWhitespaceThrowableProxyConverter"/>
	<!-- Console log output -->
	<appender name="console" class="ch.qos.logback.core.ConsoleAppender">
		<encoder>
			<pattern>${CONSOLE_LOG_PATTERN}</pattern>
		</encoder>
	</appender>

	<!-- Log file debug output -->
	<appender name="info" class="ch.qos.logback.core.rolling.RollingFileAppender">
		<file>${log.path}/info.json</file>
		<rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
			<fileNamePattern>${log.path}/%d{yyyy-MM, aux}/info.%d{yyyy-MM-dd}.%i.log.gz</fileNamePattern>
			<maxFileSize>50MB</maxFileSize>
			<maxHistory>30</maxHistory>
		</rollingPolicy>
        <!--     便于收集日志日志格式为json   -->
		<encoder class="net.logstash.logback.encoder.LoggingEventCompositeJsonEncoder">
			<providers>
				<timestamp>
					<timeZone>UTC+8</timeZone>
				</timestamp>
				<pattern>
					<pattern>
						{
						"service_name": "${server_name}",
						"timestamp": "%d{yyyy-MM-dd HH:mm:ss.SSS}",
						"log_level": "%replace(%-5level){' ', ''}",
						"ip": "%host",
						"message_key": "${server_name}-%d{yyyy-MM-dd HH:mm:ss.SSS}",
						"remote_url": "%X{req.remoteURL}",
						"remote_host": "%X{req.remoteHost}",
						"thread": "%thread",
						"class": "%class{26}#%method:%line",
						"log_info": "%msg{nolookups}",
						"exception_info": "%wEx"
						}
					</pattern>
				</pattern>
			</providers>
		</encoder>
		<filter class="ch.qos.logback.classic.filter.ThresholdFilter">
			<level>INFO</level>
		</filter>
	</appender>

	<!-- Log file error output -->
	<appender name="error" class="ch.qos.logback.core.rolling.RollingFileAppender">
		<file>${log.path}/error.log</file>
		<rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
			<fileNamePattern>${log.path}/%d{yyyy-MM}/error.%d{yyyy-MM-dd}.%i.log.gz</fileNamePattern>
			<maxFileSize>50MB</maxFileSize>
			<maxHistory>30</maxHistory>
		</rollingPolicy>
		<encoder class="net.logstash.logback.encoder.LoggingEventCompositeJsonEncoder">
			<providers>
				<timestamp>
					<timeZone>UTC+8</timeZone>
				</timestamp>
				<pattern>
					<pattern>
						{
						"service_name": "${server_name}",
						"timestamp": "%d{yyyy-MM-dd HH:mm:ss.SSS}",
						"log_level":"%replace(%-5level){' ', ''}",
						"ip": "%host",
						"message_key": "${server_name}-%d{yyyy-MM-dd HH:mm:ss.SSS}",
						"remote_url": "%X{req.remoteURL}",
						"remote_host": "%X{req.remoteHost}",
						"thread": "%thread",
						"class": "%class{26}#%method:%line",
						"log_info": "%msg{nolookups}",
						"exception_info": "%wEx"
						}
					</pattern>
				</pattern>
			</providers>
		</encoder>
		<filter class="ch.qos.logback.classic.filter.ThresholdFilter">
			<level>ERROR</level>
		</filter>
	</appender>

	<!--nacos 心跳 INFO 屏蔽-->
	<logger name="com.alibaba.nacos" level="OFF">
		<appender-ref ref="error"/>
	</logger>

	<logger name="com.alibaba.cloud.sentinel.datasource.converter" level="ERROR">
		<appender-ref ref="error"/>
	</logger>

	<!-- Level: FATAL 0  ERROR 3  WARN 4  INFO 6  DEBUG 7 -->
	<root level="INFO">
		<appender-ref ref="console"/>
		<appender-ref ref="info"/>
	</root>
</configuration>
```
## 自定义日志字段处理类XWhitespaceThrowableProxyConverter
```java
import ch.qos.logback.classic.pattern.ThrowableProxyConverter;
import ch.qos.logback.classic.spi.IThrowableProxy;
import ch.qos.logback.core.CoreConstants;

public class XWhitespaceThrowableProxyConverter extends ThrowableProxyConverter {

	@Override
	protected String throwableProxyToString(IThrowableProxy tp) {
		return super.throwableProxyToString(tp) + CoreConstants.LINE_SEPARATOR;
	}
}

```
## 自定义获取IP
```java
/**
 * @author luchaoxin
 * @date 2019-10-29
 */
@Slf4j
public class LogIpConverter extends ClassicConverter {

	private static String webIP;

	static {
		try {
			String regex = "(((\\d{1,2})|(1\\d{1,2})|(2[0-4]\\d)|(25[0-5]))\\.){3}((\\d{1,2})|(1\\d{1,2})|(2[0-4]\\d)|(25[0-5]))";
			Pattern pattern = Pattern.compile(regex);
			Enumeration<NetworkInterface> allNetInterfaces = NetworkInterface.getNetworkInterfaces();
			InetAddress inetAddress = null;
			while (allNetInterfaces.hasMoreElements()) {
				NetworkInterface netInterface = allNetInterfaces.nextElement();
				if (!netInterface.isLoopback() && !netInterface.isVirtual() && netInterface.isUp()) {
					Enumeration<InetAddress> addresses = netInterface.getInetAddresses();
					boolean hasEth0 = System.getProperty("network.interface", "eth0").equals(netInterface.getName());
					boolean isBreak = false;
					while (addresses.hasMoreElements()) {
						inetAddress = addresses.nextElement();
						if (Objects.isNull(inetAddress) || !(inetAddress instanceof Inet4Address)) {
							continue;
						}
						webIP = inetAddress.getHostAddress();
						boolean shouldBreak = hasEth0 ||
								(pattern.matcher(webIP).find() && inetAddress.isReachable(3000));
						if (shouldBreak) {
							isBreak = true;
							break;
						}
					}
					if (isBreak) {
						break;
					}
				}
			}
		} catch (Exception e) {
			webIP = "";
		}

	}

	@Override
	public String convert(ILoggingEvent event) {
		return webIP;
	}
}
```
## FileBeat 收集日志配置文件如下
```yaml
filebeat.inputs:
- type: log
  enabled: true
  json.keys_under_root: true
  json.add_error_key: true
#  json.message_key: message_key
  paths:
#    /var/datainsights-logs为所有微服务日志存放路径，所有SpringCloud 微服务docker挂载日志到本机/var/datainsights-logs，FileBeat也挂载本机目录/var/datainsights-logs
    - /var/datainsights-logs/*/info.json

#output.logstash:
#  enable: false
#  hosts: ["datainsights-logstash:5044"]
# 把日志推送到Kafka topic spring_cloud_log  
output.kafka:
  enable: true
  hosts: ["192.168.10.73:9092"]
  topic: "spring_cloud_log"
  partition.round_robin:
    reachable_only: true

```
### logstash配置文件
```yaml
input {
    tcp {
        port => 4560
        codec => json
        tags => ["4560"]
    }
# 监听kafka topic spring_cloud_log  
    kafka {
        bootstrap_servers => "192.168.10.73:9092"
        codec => json
        topics => "spring_cloud_log"
        group_id => "logstash"
        tags => ["kafka"]
    }
}

filter {
    if "5044" in [tags] or "4560" in [tags] or "kafka" in [tags] {
        mutate {
            gsub => [
                    "log_level", " ", ""
            ]
            add_tag => [ "app-log"]
            remove_field => [ "@version", "ecs", "host", "input", "agent" ]
        }
        date {
            match => [ "timestamp", "yyyy-MM-dd HH:mm:ss.SSS||yyyy-MM-dd HH:mm:ss.SSSZ" ]
            timezone => "Asia/Shanghai"
            target => "@timestamp"
        }
    }
}
output {
    stdout {codec => rubydebug}
    if "app-log" in [tags] {
        elasticsearch {
            hosts => ["es-master:9200"]
            index => "spring-cloud-%{service_name}-%{+YYYY.MM.dd}"
            manage_template => false
            # 使用新建的index template
            template_name => "spring_cloud_log_template"
            template_overwrite => true
        }
    }  else if "slow-log" in [tags] {
        elasticsearch {
            hosts => ["es-master:9200"]
            index => "mysql-slow-log-%{+YYYY.MM.dd}"
            manage_template => false
        }
    } else {
        stdout {codec => rubydebug}
    }
}
```

### 进入logstash-7.1.1执行如下命令启动logstash，filebeat待启动完毕之后就会在kibana之中看到日志索引出现
```shell script
docker-compose -f docker-compose-prod.yml up -d
```

### 在kibana Dev Tools Console  执行如下命令查询索引spring-cloud-datainsights-auth-2019.12.20的mapping
```shell script
GET spring-cloud-datainsights-auth-2019.12.20/_mapping
```
```json
{
  "spring-cloud-datainsights-auth-2019.12.20" : {
    "mappings" : {
      "properties" : {
        "@timestamp" : {
          "type" : "date"
        },
        "agent" : {
          "properties" : {
            "ephemeral_id" : {
              "type" : "keyword"
            },
            "hostname" : {
              "type" : "keyword"
            },
            "id" : {
              "type" : "keyword"
            },
            "type" : {
              "type" : "keyword"
            },
            "version" : {
              "type" : "keyword"
            }
          }
        },
        "class" : {
          "type" : "keyword"
        },
        "exception_info" : {
          "type" : "text",
          "fields" : {
            "keyword" : {
              "type" : "keyword",
              "ignore_above" : 256
            }
          }
        },
        "ip" : {
          "type" : "keyword"
        },
        "log" : {
          "properties" : {
            "file" : {
              "properties" : {
                "path" : {
                  "type" : "text",
                  "fields" : {
                    "keyword" : {
                      "type" : "keyword",
                      "ignore_above" : 256
                    }
                  }
                }
              }
            },
            "offset" : {
              "type" : "long"
            }
          }
        },
        "log_info" : {
          "type" : "text",
          "analyzer" : "ik_max_word",
          "search_analyzer" : "ik_smart"
        },
        "log_level" : {
          "type" : "keyword"
        },
        "logger" : {
          "type" : "keyword"
        },
        "message_key" : {
          "type" : "text",
          "fields" : {
            "keyword" : {
              "type" : "keyword",
              "ignore_above" : 256
            }
          }
        },
        "remote_host" : {
          "type" : "text",
          "fields" : {
            "keyword" : {
              "type" : "keyword",
              "ignore_above" : 256
            }
          }
        },
        "remote_url" : {
          "type" : "text",
          "fields" : {
            "keyword" : {
              "type" : "keyword",
              "ignore_above" : 256
            }
          }
        },
        "server_name" : {
          "type" : "keyword"
        },
        "service_name" : {
          "type" : "text",
          "fields" : {
            "keyword" : {
              "type" : "keyword",
              "ignore_above" : 256
            }
          }
        },
        "tags" : {
          "type" : "text",
          "fields" : {
            "keyword" : {
              "type" : "keyword",
              "ignore_above" : 256
            }
          }
        },
        "thread" : {
          "type" : "keyword"
        },
        "timestamp" : {
          "type" : "date",
          "format" : "yyyy-MM-dd HH:mm:ss||yyyy-MM-dd||epoch_millis||yyyy-MM-dd'T'HH:mm:ss||yyyy-MM-dd'T'HH:mm:ss.SSSZ||yyyy-MM-dd HH:mm:ss.SSS||yyyy-MM-dd HH:mm:ss.SSSZ"
        }
      }
    }
  }
}
```
## 生成的索引列表
![生成的索引列表](https://github.com/lucky-xin/docker-elk/blob/master/.img/index-list.png)
## 生成的数据预览
![生成的数据预览](https://github.com/lucky-xin/docker-elk/blob/master/.img/index-json-detail.png)
## 生成的json数据详情
![生成的json数据详情](https://github.com/lucky-xin/docker-elk/blob/master/.img/data-preview.png)
