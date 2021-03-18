# 已发现的设备字典
foundDeviceMap = null
# 连接的设备ID
connectDeviceId = null
# 连接回调函数
connectCallback = null
# 蓝牙服务 uuid
serviceUUID = null
# 超时时间
connectTime = 20 * 1000
reqTime = 240
resTime = 1000
# 超时计数器
connectTimer = null
reqTimer = null
resTimer = null

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
		console.log device
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
				serviceUUID = res.services[0].uuid
				# # 开始获取检查目标特征
				# startGetAndCheckCharacterisitc()
				# 监听数据
				monitorNotification()
		fail: =>
			clearTimeout connectTimer
			connectCallback && connectCallback '获取服务失败'

###
 # 获取并检查特征
###
# startGetAndCheckCharacterisitc = ->
# 	wx.getBLEDeviceCharacteristics
# 		deviceId: connectDeviceId
# 		serviceId: serviceUUID
# 		success: (res) =>
# 			console.log res.characteristics
# 			let haveRead = false
# 			let haveWrite = false
# 			for (let i = 0; i < res.characteristics.length; i++) {
# 				let itemUUID = res.characteristics[i].uuid
# 				if (itemUUID == readUUID) {
# 					haveRead = true
# 				}
# 				else if (itemUUID == writeUUID) {
# 					haveWrite = true
# 				}
# 				if (haveRead == true && haveWrite == true) {
# 					break
# 				}
# 			}
# 			if (haveRead == true && haveWrite == true) {
# 				//监听数据
# 				monitorNotification()
# 			}
# 			else {
# 				if (typeof connectTimer != undefined) clearTimeout(connectTimer)
# 				typeof connectCallback == FUNCTION && connectCallback(codeEnum.noTargetCharacteristic)
# 			}
# 		},
# 		fail: function () {
# 			if (typeof connectTimer != undefined) clearTimeout(connectTimer)
# 			typeof connectCallback == FUNCTION && connectCallback(codeEnum.getCharacteristicsFailure)
# 		}
# 	})
# }

###
 # 监听数据
###
# monitorNotification = ->
# 	wx.notifyBLECharacteristicValueChange({
# 		deviceId: connectDeviceId,
# 		serviceId: serviceUUID,
# 		characteristicId: readUUID,
# 		state: true,
# 		success: function (res) {
# 		},
# 		fail: function () {
# 			if (typeof connectTimer != undefined) clearTimeout(connectTimer)
# 			typeof connectCallback == FUNCTION && connectCallback(codeEnum.monitorNotificationFailure)
# 		}
# 	})

# 	wx.onBLECharacteristicValueChange(function (res) {
# 		if (res.deviceId = connectDeviceId && res.serviceId == serviceUUID && res.characteristicId == readUUID) {
# 			//解析数据
# 			analyticData(res.value)
# 		}
# 	})
# }

module.exports = {
	start
}
