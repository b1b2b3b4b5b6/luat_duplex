## communication process

```sequence
Title: communication process
air->esp32: packet 
esp32->air: ack packet
esp32->air: packet 
air->esp32: ack packet
```

​	this way make sure that if recving ack, the data must be sended success, but not be responsible for fail or receive error

## protocol

### frame format

| type      | start bytes | payload len  | payload | crc8 |
| --------- | ----------- | ------------ | ------- | ---- |
| len(byte) | 2           | 2(big-edian) | /       | 1    |
| content   | 0x00,0x00   | /            | /       | /`   |

> `payload len` max len 1472
>
> `crc8` calculate for start bytes, payload len and payload 

### packet format

#### send

| type      | packet id   | ack type | packet buf |
| --------- | ----------- | -------- | ---------- |
| len(byte) | 1           | 1        | /          |
| content   | 0x01 ~ 0xFF | 2/3      | /          |

#### ack

|           | packet id   | ack type | packet buf |
| --------- | ----------- | -------- | ---------- |
| len(byte) | 1           | 1        | /          |
| content   | 0x01 ~ 0xFF | 2        | /          |

##### ack type

| ack type     | size | value |
| ------------ | ---- | ----- |
| not need ack | 1    | 1     |
| need ack     | 1    | 2     |
| this is ack  | 1    | 3     |



### protocol format

|           | data type | data |
| --------- | --------- | ---- |
| len(byte) | 1         | /    |

#### data type

| data type | size | value |
| --------- | ---- | ----- |
| BIN       | 1    | 1     |
| STR       | 1    | 2     |



## application 

### esp > air

#### Info

device status

```json
{
    "Typ":"Info",
    "Mac":"00:00:00:00:00:00",
    "CusData":{}
}
```



### air > esp

#### Control

set deivce status

```json
{
    "Cmd":"Control",
    "Mac":"00:00:00:00:00:00",
    "CusData":{}
}
```



#### Ota

air initiate the ota progress

```json
{
    "Cmd": "Ota",
    "Devices":[],
	"CusData":{
	    "Typ": "TEMP_CONTROL",
	    "PeroidMs":100,
	    "IsHttp":0
	}
}
```



