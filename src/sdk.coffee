# 已发现的设备字典
foundDeviceMap = null
# 连接的设备ID
connectDeviceId = null
# 连接回调函数
connectCallback = null
# 蓝牙服务 uuid
serviceUUID = '0000AE00-0000-1000-8000-00805F9B34FB'
readUUID = '0000AE02-0000-1000-8000-00805F9B34FB'
writeUUID = '0000AE01-0000-1000-8000-00805F9B34FB'
# 超时时间
connectTime = 20 * 1000
reqTime = 240
resTime = 1000
# 超时计数器
connectTimer = null
reqTimer = null
resTimer = null
# 一帧数据
frame = ''
# 一帧数据的长度
frameLen = 0
# 数据集
frames = []
# 数据集的长度
framesLen = 0
# 接收数据处理回调
dataHandlerCallback = null
# 发送buffer数组
sendBufferArray = []
# 发送下标
sendIndex = 0
# 重发次数
resendCount = 3

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
 # deviceId: 蓝牙设备ID
 # callback: 连接结果回调函数 (errMsg) => {}
###
start = (deviceId, callback) ->
	connectDeviceId = deviceId
	connectCallback = callback
	scanBleDevice (device) =>
		console.log '发现设备：', device
		connectBleDevice() if device.deviceId is connectDeviceId

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
			errMsg = '根据指定 deviceId 获取到了多个服务' if res.services.length > 1
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
			console.log '监听成功，'
			wx.onBLECharacteristicValueChange (res) =>
				if res.deviceId is connectDeviceId and res.serviceId is serviceUUID and res.characteristicId is readUUID
					# 解析数据
					analyticData res.value
		fail: =>
			clearTimeout connectTimer
			connectCallback && connectCallback '监听数据失败'

###
 # 解析数据
###
analyticData = (value) ->
	data = dataHandler.bufferArrayToHexString value
	console.log '接收：', data
# 	if frame.length is 0
# 		frameLen = parseInt(data.slice(4, 8), 16) * 2
# 	frame += data
# 	if (frame.length > frameLen) {
# 		frame = ""
# 		frameLen = 0
# 		typeof dataHandlerCallback == FUNCTION && dataHandlerCallback(codeEnum.dataFrameTransboundary, "", "数据长度越界")
# 	}
# 	else if (frame.length == frameLen) {
# 		let bCmdId = frame.slice(8, 12)
# 		if (bCmdId === "2711") {
# 			frame = ""
# 			frameLen = 0
# 			//收到authrequest握手包，回复
# 			sendDataToDevice(dataUtil.makeAuthResponse(), (code, data, msg) => {
# 				if (code != 0) {
# 					if (typeof connectTimer != undefined) clearTimeout(connectTimer)
# 					typeof connectCallback == FUNCTION && connectCallback(codeEnum.authResponseFailure)
# 				}
# 			})
# 		}
# 		else if (bCmdId === "2713") {
# 			frame = ""
# 			frameLen = 0
# 			//收到initrequest握手包，回复
# 			sendDataToDevice(dataUtil.makeInitResponse(), (code, data, msg) => {
# 				if (code != 0) {
# 					if (typeof connectTimer != undefined) clearTimeout(connectTimer)
# 					if (typeof start80Timer != undefined) clearTimeout(start80Timer)
# 					typeof connectCallback == FUNCTION && connectCallback(codeEnum.initResponseFailure)
# 				}
# 			})
# 			//延时，发设备握手包
# 			start80Timer = setTimeout(() => {
# 				//发送设备初始化数据
# 				initDevice()
# 				//一段时间没任何相应，重发一次
# 				wait80ResponseTimer = setTimeout(() => {
# 					initDevice()
# 				}, wait80ResponseTime)
# 			}, start80Time)
# 		}
# 		else if (bCmdId === "2712") {
# 			let outWechatFrame = frame.slice(16)
# 			let outProtoFrame = outWechatFrame.slice(8, -6)
# 			frame = ""
# 			frameLen = 0
# 			if (frames.length == 0) {
# 				let ctl = parseInt(outProtoFrame.slice(2, 6), 16)
# 				framesLen = ctl - 0x8000
# 			}
# 			frames.push(outProtoFrame)
# 			if (frames.length == framesLen) {
# 				let allPaseBCC = true
# 				for (let i = 0; i < frames.length; i++) {
# 					let itemFrame = frames[i]
# 					let bcc = 0
# 					for (let j = 0; j < parseInt(itemFrame.length / 2) - 1; j++) {
# 						let bit = parseInt(itemFrame.slice(j * 2, (j + 1) * 2), 16)
# 						bcc ^= bit
# 					}
# 					if (bcc != parseInt(itemFrame.slice(-2), 16)) {
# 						allPaseBCC = false
# 						break;
# 					}
# 				}
# 				if (allPaseBCC == false) {
# 					frames = new Array()
# 					framesLen = 0
# 					typeof dataHandlerCallback == FUNCTION && dataHandlerCallback(codeEnum.notPassBccCheck, "", "bcc校验不通过")
# 				}
# 				else {
# 					let completeData = ""
# 					for (let i = 0; i < frames.length; i++) {
# 						let itemFrame = frames[i]
# 						completeData += itemFrame.slice(8, -2)
# 					}
# 					frames = new Array()
# 					framesLen = 0
# 					typeof dataHandlerCallback == FUNCTION && dataHandlerCallback(codeEnum.successCode, completeData, "成功")
# 				}
# 			}
# 		}
# 		else {
# 			console.log("奇异数据")
# 			frame = ""
# 			frameLen = 0
# 		}
# 	}
# }

###
 # 发送数据到设备
 # bufferArray: 通过dataUtil接口获取相应到的bufferArray的数据
 # callback: 结果回调，(errMsg, data) => {}
###
sendDataToDevice = (commandList, callback) ->
	# TODO
	bufferArray = makeFrame commandList
	console.log bufferArray
	# bufferArray = []
	# bufferArray.push makeFrame command for command in commandList
	dataHandlerCallback = callback
	sendBufferArray = [ bufferArray ]
	sendIndex = 0
	frame = ''
	frameLen = 0
	frames = []
	framesLen = 0
	runningSendData()

###
 # 连续发送待发数据
###
runningSendData = ->
	value = sendBufferArray[sendIndex]
	console.log '发送：', value
	# let hex = dataHandler.bufferArrayToHexString(value)
	# console.log("发送：" + hex)
	wx.writeBLECharacteristicValue
		deviceId: connectDeviceId
		serviceId: serviceUUID
		characteristicId: writeUUID
		value: value
		success: (res) =>
			sendIndex++
			resendCount = 3
			runningSendData() if sendIndex < sendBufferArray.length
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
	command = parseInt command
	param = data.substr 2, 2
	arr.push param
	param = parseInt param
	check = (command ^ param).toString 16
	check = '0' + check if check.length < 2
	arr.push check
	arr.push '8f'
	# "f8#{ data }#{ check }8f"
	bufferArray = []
	bufferArray.push hexStringToBufferArray byte for byte in arr
	bufferArray

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
# bufferArrayToHexString = (bufferArray) ->
# 	hex = Array.prototype.map.call new Uint8Array(bufferArray), (x) => "00#{ x.toString 16 }".slice -2
# 	hex.join ''

module.exports = {
	start
	sendDataToDevice
}
