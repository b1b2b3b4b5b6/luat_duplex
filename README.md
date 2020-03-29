#luat_duplex

#### device: air202

#### framework: LuaTask

### API
require "duplex"

`duplex.sendstr(data, time_ms)`

> ```
> -- send str to serial
> -- @string data
> -- @number time_ms, send time out[ms]
> -- @return bool, true indicate that the str must be received by target, false means that target receiving status is unknown
> -- @usage duplex.sendstr("i am str", 3000) send "i am str" to serial, wait 3000 ms if not success
> ```



`duplex.recv()`

> ```
> -- wait recv data, block forever
> -- @return string, recv data
> -- @usage data = duplex.recv(), wati until recv data
> ```

