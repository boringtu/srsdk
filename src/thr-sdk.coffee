# 已发现的设备字典
foundDeviceMap = null
# 连接的设备ID
connectDeviceId = null
# 连接的设备的MAC地址
connectDeviceMAC = null
# 设备型号（只支持两种：'001'、'007'）
connectDeviceType = '007'
# 连接回调函数
connectCallback = null
# 是否正在连接
isConnecting = 0
# 蓝牙服务 uuid
serviceUUID = '0000AE00-0000-1000-8000-00805F9B34FB'
readUUID = '0000AE02-0000-1000-8000-00805F9B34FB'
writeUUID = '0000AE01-0000-1000-8000-00805F9B34FB'
# 超时时间
connectTime = 20 * 1000
reqTime = 240
resTime = 1000
# 连接超时句柄
connectTimer = null
# 自动重连心跳句柄
autoConnectTimer = null
reqTimer = null
resTimer = null
# 接收数据处理回调
dataHandlerCallback = null
# 发送buffer数组
sendBufferArray = []
# 发送下标
sendIndex = 0
# 重发次数
resendCount = 3
# 是否正在重连
isTryingRestart = 0

# 通道
channel = 1
# 设备工作模式（1: 自购；2: 共享）
connectDeviceWorkMode = 2
# 数据缓存（暂时只缓存了强度
dataCache =
	1:
		c: '00'
	2:
		c: '00'

# # 是否正在切换通道
# isSwitchingChannel = 0
# # 等待同步结束的 setTimeout 句柄
# waitingToSwitchChannel = null
# # 从设备同步来的数据
# syncData = {}

openBluetoothAdapter = -> new Promise (resolve) =>
	console.log '开启蓝牙适配器'
	wx.openBluetoothAdapter
		success: (res) =>
			console.log '开启蓝牙适配器成功'
			resolve 1
		fail: (res) =>
			console.error '开启蓝牙适配器失败'
			console.error res
			resolve 0

startBluetoothDevicesDiscovery = -> new Promise (resolve) =>
	console.log '开始搜索新设备'
	wx.startBluetoothDevicesDiscovery
		# services: ['fee7']
		allowDuplicatesKey: true
		success: (res) =>
			console.log '开始搜索新设备成功'
			resolve 1
		fail: (res) =>
			console.error '开始搜索新设备失败'
			resolve 0

stopBluetoothDevicesDiscovery = -> new Promise (resolve) =>
	console.log '停止搜索新设备'
	wx.stopBluetoothDevicesDiscovery
		success: (res) =>
			console.log '停止搜索成功'
			resolve 1
		fail: (res) =>
			console.error '停止搜索失败'
			resolve 0

###
 # 开始入口
 # @param {String} mac 蓝牙设备MAC地址
 # @param {String} deviceType 蓝牙设备型号（只支持两种：'001'、'007'）
 # @param {Function} callback 连接结果回调函数 (errMsg) => {}
###
start = (mac = connectDeviceMAC, deviceType = connectDeviceType, workMode = connectDeviceWorkMode, callback = connectCallback) ->
	return if connectDeviceId and not isTryingRestart
	isTryingRestart = 0
	console.log '开始：', arguments
	connectDeviceMAC = mac
	connectDeviceType = deviceType
	connectCallback = callback
	connectDeviceWorkMode = workMode
	scanBleDevice (device) =>
		# connectBleDevice() if device.deviceId is connectDeviceId
		temp = bufferArrayToHexString device.advertisData
		currMAC = []
		currMAC.push temp.substr(i * 2, 2).toLocaleUpperCase() for i in [...new Array(temp.length / 2).keys()]
		currMAC = currMAC.join ':'
		console.log '发现设备：', device, currMAC
		if currMAC is connectDeviceMAC
			connectDeviceId = device.deviceId
			connectBleDevice()

###
 # 结束入口
 # @param {Function} callback 连接结果回调函数 (errMsg) => {}
###
end = (callback) ->
	console.log '治疗结束，断开蓝牙连接'
	clearInterval autoConnectTimer
	wx.closeBLEConnection
		deviceId: connectDeviceId
		success: (res) =>
			# 重置各种数据状态
			foundDeviceMap = null
			connectDeviceId = null
			connectDeviceMAC = null
			connectDeviceType = '007'
			connectCallback = null
			dataHandlerCallback = null
			channel = 1
			connectDeviceWorkMode = 2
			dataCache =
				1:
					c: '00'
				2:
					c: '00'
			callback && callback()
		fail: =>
			callback && callback '断开蓝牙连接失败'

###
 # 搜索设备
 # callback: 搜索回调 (device) => {}
###
scanBleDevice = (callback) ->
	foundDeviceMap = {}
	# 开启蓝牙适配器
	return unless await openBluetoothAdapter()
	# 开始搜索新设备
	return unless await startBluetoothDevicesDiscovery()

	console.log '监听寻找新设备'
	wx.onBluetoothDeviceFound (res) =>
		for device, i in res.devices
			isExisted = 0
			isExisted = 1 if foundDeviceMap[device.deviceId]
			continue if isExisted
			foundDeviceMap[device.deviceId] = device
			callback && callback device

###
 # 连接设备
###
connectBleDevice = ->
	clearTimeout connectTimer
	clearTimeout reqTimer
	clearTimeout resTimer
	connectTimer = setTimeout =>
		connectCallback && connectCallback '连接设备超时'
	, connectTime
	if await stopBluetoothDevicesDiscovery()
		# 开始连接
		startConnectBle()
	else
		clearTimeout connectTimer
		connectCallback && connectCallback '停止搜索设备失败'

###
 # 开始连接
###
startConnectBle = ->
	wx.createBLEConnection
		deviceId: connectDeviceId
		success: (res) =>
			# 获取服务
			startGetService()
		fail: =>
			clearTimeout connectTimer
			connectCallback && connectCallback '创建连接失败'

###
 # 开始获取服务
###
startGetService = ->
	console.log '开始获取服务'
	wx.getBLEDeviceServices
		deviceId: connectDeviceId
		success: (res) =>
			console.log '成功获取服务', res.services
			errMsg = '根据指定 deviceId 未获取到服务' if res.services.length is 0
			# errMsg = '根据指定 deviceId 获取到了多个服务' if res.services.length > 1
			if errMsg
				clearTimeout connectTimer
				connectCallback && connectCallback errMsg
			else
				haveService = false
				for item in res.services
					itemUUID = item.uuid
					if itemUUID is serviceUUID
						haveService = true
						break
				console.log 'haveService: ', haveService
				if haveService
					# 开始获取检查目标特征
					startGetAndCheckCharacterisitc()
				else
					connectCallback && connectCallback '未检测到必须服务'
		fail: =>
			clearTimeout connectTimer
			connectCallback && connectCallback '获取服务失败'

###
 # 获取服务下的读写特征
###
startGetAndCheckCharacterisitc = ->
	console.log '获取服务下的读写特征'
	wx.getBLEDeviceCharacteristics
		deviceId: connectDeviceId
		serviceId: serviceUUID
		success: (res) =>
			console.log '发现特征列表：', res.characteristics
			step = 0
			for item in res.characteristics
				itemUUID = item.uuid
				if itemUUID is readUUID
					step = step | 0x01
				else if itemUUID is writeUUID
					step = step | 0x02
				break if step is 3
			if step is 3
				# 监听数据
				monitorNotification()
			else
				clearTimeout connectTimer
				connectCallback && connectCallback '未找到目标特征'
		fail: =>
			clearTimeout connectTimer
			connectCallback && connectCallback '获取特征失败'

###
 # 监听数据
###
monitorNotification = ->
	console.log '监听数据'
	wx.notifyBLECharacteristicValueChange
		deviceId: connectDeviceId
		serviceId: serviceUUID
		characteristicId: readUUID
		state: true
		success: (res) =>
			console.log '监听成功'
			connectCallback && connectCallback()
			connectCallback = null
			# 设置设备工作类型（自购 / 共享）
			sendDataToDevice [ "f10#{ connectDeviceWorkMode }" ]
			# 启动自动重连服务
			autoReconnect()
			wx.onBLECharacteristicValueChange (res) =>
				if res.deviceId is connectDeviceId and res.serviceId is serviceUUID and res.characteristicId is readUUID
					# 解析数据
					analyticData res.value
		fail: =>
			clearTimeout connectTimer
			connectCallback && connectCallback '监听数据失败'

###
 # 自动重连服务
###
autoReconnect = ->
	clearInterval autoConnectTimer
	autoConnectTimer = setInterval =>
		console.log '尝试获取设备服务信息'
		wx.getBLEDeviceServices
			deviceId: connectDeviceId
			fail: =>
				clearInterval autoConnectTimer
				console.warn '获取设备服务信息失败，开始尝试重连'
				# 尝试重连
				isTryingRestart = 1
				start()
	, 1000

###
 # 解析数据
###
analyticData = (value) ->
	data = bufferArrayToHexString value
	console.log '接收：', data

	# return unless isSwitchingChannel
	# # 新协议处理逻辑
	# data = data.slice 2, -2
	# arr = []
	# for i in [...new Array(Math.floor data.length / 6).keys()]
	# 	temp = data.substr i * 6, 6
	# 	cmd = temp.substr 0, 2
	# 	val = temp.substr 2, 2
	# 	syncData[cmd] = val
	# _switchChannel()

	# # 旧协议处理逻辑
	# clearTimeout waitingToSwitchChannel
	# cmd = data.substr 2, 2
	# val = data.substr 4, 2
	# syncData[cmd] = val
	# waitingToSwitchChannel = setTimeout _switchChannel, 200

###
 # 发送数据到设备
 # bufferArray: 通过dataUtil接口获取相应到的bufferArray的数据
 # callback: 结果回调，(errMsg, data) => {}
###
sendDataToDevice = (commandList, callback) ->
	bufferArray = []
	bufferArray.push makeFrame command for command in commandList
	dataHandlerCallback = callback
	sendBufferArray = bufferArray
	sendIndex = 0
	runningSendData()

###
 # 连续发送待发数据
###
runningSendData = ->
	value = sendBufferArray[sendIndex]
	console.log '发送：', bufferArrayToHexString value
	wx.writeBLECharacteristicValue
		deviceId: connectDeviceId
		serviceId: serviceUUID
		characteristicId: writeUUID
		value: value
		success: (res) =>
			console.log '响应：', res
			sendIndex++
			resendCount = 3
			if sendIndex < sendBufferArray.length
				setTimeout =>
					runningSendData()
				, 10
			else
				dataHandlerCallback?()
		fail: (res) =>
			console.warn res
			if resendCount > 0
				resendCount--
				setTimeout =>
					console.log "第#{ 3 - resendCount }次重发"
					runningSendData()
				, 200
			else
				dataHandlerCallback && dataHandlerCallback '发送数据失败'

###
 # 封包
 # data: 命令码 + 参数
 # return 完整命令帧：报头 + 命令码 + 参数 + 校验码 + 报尾
###
makeFrame = (data) ->
	arr = []
	arr.push 'f8'
	command = data.substr 0, 2
	arr.push command
	command = parseInt command, 16
	param = data.substr 2, 2
	arr.push param
	param = parseInt param, 16
	check = (command ^ param).toString 16
	check = '0' + check if check.length < 2
	arr.push check
	arr.push '8f'
	hexStringToBufferArray "f8#{ data }#{ check }8f".toLocaleUpperCase()

###
 # 将hexString转成bufferArray
###
hexStringToBufferArray = (hexString) ->
	bufferArray = new Uint8Array hexString.match(/[\da-f]{2}/gi).map (h) =>
		parseInt h, 16
	bufferArray.buffer

###
 # 将bufferArray转成hexString
###
bufferArrayToHexString = (bufferArray) ->
	hex = Array.prototype.map.call new Uint8Array(bufferArray), (x) => "00#{ x.toString 16 }".slice -2
	hex.join ''

###
 # 调整强度
 # @param {Number} num 强度（0 ~ 99）
###
adjustStrength = (num) -> new Promise (resolve) =>
	throw new Error 'param mast be a number' if isNaN num
	num = 0 if num < 0
	num = 99 if num > 99
	console.log "调整强度：#{ num }"
	num = (+num).toString 16
	num = '0' + num if num.length < 2
	cmd = 'c' + channel + num
	dataCache[channel].c = num
	sendDataToDevice [ 'd101', "e10#{ channel }", cmd ], (msg) => resolve msg

###
 # 重置强度 将所有通道的强度归零
###
resetStrengths = -> new Promise (resolve) =>
	console.log '重置强度，将所有通道的强度归零'
	dataCache[1].c = '00'
	dataCache[2].c = '00'
	sendDataToDevice [ 'c100', 'c200' ], (msg) => resolve msg

###
 # 调整治疗时间
 # @param {Number} num 倒计时时间（单位：m）
###
adjustCDTime = (num) -> new Promise (resolve) =>
	throw new Error 'param mast be a number' if isNaN num
	is001 = connectDeviceType is '001'
	num = 0 if num < 0
	num = 90 if num > 90 and is001
	num = 99 if num > 99
	console.log "调整时间：#{ num }m"
	num = Math.ceil num / 10 if is001
	num = (+num).toString 16
	num = '0' + num if num.length < 2
	# cmd = 'a' + channel + num
	# sendDataToDevice [ 'd101', "e10#{ channel }", cmd ], (msg) => resolve msg
	sendDataToDevice [ 'd101', "a1#{ num }", "a2#{ num }" ], (msg) => resolve msg

###
 # 切换通道（只有'007'才有此功能）
 # @param {Number} num 通道号（可选：1、2）
###
switchChannel = (num) -> new Promise (resolve) =>
	throw new Error 'param mast be a number' if isNaN num
	console.log "切换到通道：#{ num }"
	num = 1 if num < 1
	num = 2 if num > 2
	channel = num
	# sendDataToDevice [ 'd101', "e10#{ channel }", "c#{ channel }#{ dataCache[channel].c }" ], (msg) => resolve msg
	sendDataToDevice [ "e10#{ channel }" ], (msg) => resolve msg

	# isSwitchingChannel = 1
	# syncData = {}
	# sendDataToDevice [ 'f1fc' ], (msg) => resolve msg

# TODO 应该已废弃
# _switchChannel = ->
# 	isSwitchingChannel = 0
# 	waitingToSwitchChannel = null
# 	console.log '开始切换通道'
# 	old = 3 - channel
# 	# cmds = [ 'c101', 'a100' ]
# 	cmds = []
# 	# 通道
# 	cmds.push "e10#{ channel }"
# 	# 强度
# 	# cVal = syncData['c' + old]
# 	# cmds.push "c#{ channel }#{ cVal }"
# 	# cmds.push "c#{ channel }00"
# 	# 时间（因为机器时间精确度只能到分，所以切换时要 +1，但结束时间要以界面为准
# 	aVal = syncData['a' + old]
# 	aVal = parseInt aVal, 16
# 	aVal += 1
# 	aVal = aVal.toString 16
# 	aVal = '0' + aVal if aVal.length < 2
# 	# 共享模式不需要改变对应通道的时间，时间是共享的
# 	cmds.push "a#{ channel }#{ aVal }" unless +connectDeviceWorkMode is 2
# 	# cmds.push "c#{ old }00"
# 	# cmds.push "a#{ old }00"
# 	# cmds.push 'd101'
# 	sendDataToDevice cmds
# 	# do (old) => setTimeout =>
# 	# 	cmds = []
# 	# 	cmds.push "c#{ old }00"
# 	# 	cmds.push "a#{ old }00"
# 	# 	sendDataToDevice cmds
# 	# , 2000

exports = {
	start
	end
	sendDataToDevice
	adjustStrength
	adjustCDTime
	switchChannel
	resetStrengths
	hexStringToBufferArray
	bufferArrayToHexString
}

Object.defineProperties exports,
	channel: get: => channel

module.exports = exports
