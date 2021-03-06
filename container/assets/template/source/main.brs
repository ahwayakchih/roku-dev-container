' Use RunUserInterface instead of Main, so we can run tests with Roca
sub RunUserInterface(argsAA as Object)
	'Indicate this is a Roku SceneGraph application'
	screen = CreateObject("roSGScreen")
	m.port = CreateObject("roMessagePort")
	screen.setMessagePort(m.port)

	'Create a scene and load /components/MainScene.xml'
	screen.CreateScene("MainScene")
	screen.show()

	'bs:disable-next-line
	if type(Rooibos_Init) = "Function" then Rooibos_Init()

	while true
		msg = wait(0, m.port)
		msgType = type(msg)
		if msgType = "roSGScreenEvent"
			if msg.isScreenClosed() then return
		end if
	end while
end sub