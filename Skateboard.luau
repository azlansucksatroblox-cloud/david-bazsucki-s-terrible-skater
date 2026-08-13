local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local manualGui = playerGui:WaitForChild("ManualGui")
local noseManualGui = playerGui:WaitForChild("NoseManualGui")

local comboGui = playerGui.ComboGui
local comboLabel = comboGui.ComboLabel
local tricksLabel = comboGui.TricksLabel

comboLabel.Text = ""
tricksLabel.Text = ""

local grindGui = playerGui:WaitForChild("GrindGui")
local grindBar = grindGui.Bar
local grindMarker = grindBar.Marker

local scoreGui = playerGui:WaitForChild("ScoreGui")
local scoreLabel = scoreGui:WaitForChild("ScoreImage"):WaitForChild("ScoreLabel")

local countingSFX = game.SoundService:WaitForChild("CountingSFX")
local completeSFX = game.SoundService:WaitForChild("CompleteSFX")

local RS = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")

local spawnEvent = game.ReplicatedStorage:WaitForChild("Spawn")
local ollieEvent = game.ReplicatedStorage:WaitForChild("Ollie")
local valueEvent = game.ReplicatedStorage:WaitForChild("Value")
local ragdollModule = require(game.ReplicatedStorage:WaitForChild("Ragdoll"))

local tweenInfo = TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local feedbackGui = playerGui:WaitForChild("FeedbackGui")

local GREATFeedback = {
	feedbackGui:WaitForChild("Gnarly"),
	feedbackGui:WaitForChild("Steezy"),
	feedbackGui:WaitForChild("Holy"),
	feedbackGui:WaitForChild("Lethal"),
}

local goodFeedback = {
	feedbackGui:WaitForChild("Clean"),
	feedbackGui:WaitForChild("Bolts"),
	feedbackGui:WaitForChild("Sick"),
	feedbackGui:WaitForChild("Nice"),
	feedbackGui:WaitForChild("Woah"),
	feedbackGui:WaitForChild("Rad"),

}

local badFeedback = {
	feedbackGui:WaitForChild("Cuss"),
	feedbackGui:WaitForChild("Noob"),
	feedbackGui:WaitForChild("Poser"),
	feedbackGui:WaitForChild("Sucks"),
	feedbackGui:WaitForChild("Idiot"),
	feedbackGui:WaitForChild("Boo"),
	feedbackGui:WaitForChild("Yikes")
}

local char, humanoid, hrp, animator
local idleTrack, pushTrack, ollieTrack, popShuvTrack, frontShuvTrack, kickflipTrack, heelflipTrack, manualTrack, noseManualTrack, fiftyfiftyGrindTrack, BSBoardSlideTrack, FSBoardSlideTrack
local animTable = {}

local boardSessionId = 0
local boardConnections = {}

local function TrackConnection(conn)
	table.insert(boardConnections, conn)
	return conn
end

local function CleanupBoardSession()
	for _, conn in ipairs(boardConnections) do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	boardConnections = {}
end


local function LoadAnimations()
	animator = humanoid:WaitForChild("Animator")

	idleTrack = animator:LoadAnimation(script:WaitForChild("Idle"))
	pushTrack = animator:LoadAnimation(script:WaitForChild("Push"))
	ollieTrack = animator:LoadAnimation(script:WaitForChild("Ollie"))
	popShuvTrack = animator:LoadAnimation(script:WaitForChild("PopShuv"))
	frontShuvTrack = animator:LoadAnimation(script:WaitForChild("FrontShuv"))
	kickflipTrack = animator:LoadAnimation(script:WaitForChild("KickFlip"))
	heelflipTrack = animator:LoadAnimation(script:WaitForChild("HeelFlip"))
	manualTrack = animator:LoadAnimation(script:WaitForChild("Manual"))
	noseManualTrack = animator:LoadAnimation(script:WaitForChild("NoseManual"))
	fiftyfiftyGrindTrack = animator:LoadAnimation(script:WaitForChild("Grind01"))
	BSBoardSlideTrack = animator:LoadAnimation(script:WaitForChild("Grind02"))
	FSBoardSlideTrack = animator:LoadAnimation(script:WaitForChild("Grind03"))

	animTable = {
		idleTrack, pushTrack, ollieTrack, popShuvTrack,
		frontShuvTrack, kickflipTrack, heelflipTrack, manualTrack, fiftyfiftyGrindTrack
	}

	frontShuvTrack.Looped = false
	frontShuvTrack.Priority = Enum.AnimationPriority.Action3
	popShuvTrack.Priority = Enum.AnimationPriority.Action2
	heelflipTrack.Looped = false
	heelflipTrack.Priority = Enum.AnimationPriority.Action2
	kickflipTrack.Looped = false
	kickflipTrack.Priority = Enum.AnimationPriority.Action2
	idleTrack.Looped = true
	idleTrack.Priority = Enum.AnimationPriority.Idle
	ollieTrack.Priority = Enum.AnimationPriority.Action
	pushTrack.Looped = false
	pushTrack.Priority = Enum.AnimationPriority.Movement
end

local function SetupCharacter(newChar)
	CleanupBoardSession()
	boardSessionId += 1

	char = newChar
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:WaitForChild("HumanoidRootPart")
	LoadAnimations()
end

SetupCharacter(player.Character or player.CharacterAdded:Wait())
player.CharacterAdded:Connect(SetupCharacter)


local function IsGrindableRail(instance)
	if not instance then return false end
	if instance.Name == "Rail" then return true end
	if instance:GetAttribute("IsGrindable") == true then return true end
	return false
end

local function RailAxis(rail)
	local cf = rail.CFrame
	local size = rail.Size

	if size.X >= size.Y and size.X >= size.Z then
		return cf.RightVector, size.X
	elseif size.Y >= size.X and size.Y >= size.Z then
		return cf.UpVector, size.Y
	else
		return cf.LookVector, size.Z
	end
end

local function ClosestPointOnRail(rail, point)
	local railCF = rail.CFrame
	local axisVector, length = RailAxis(rail)
	local halfLength = length / 2

	local startPoint = railCF.Position - axisVector * halfLength
	local endPoint = railCF.Position + axisVector * halfLength

	local railVector = endPoint - startPoint
	local t = (point - startPoint):Dot(railVector) / railVector:Dot(railVector)
	t = math.clamp(t, 0, 1)

	return startPoint + railVector * t, t
end

spawnEvent.OnClientEvent:Connect(function(skateboard)

	local ownerId = skateboard:GetAttribute("OwnerUserId")
	if ownerId and ownerId ~= player.UserId then
		return
	end

	CleanupBoardSession()
	boardSessionId += 1
	local mySession = boardSessionId

	local function stillActive()
		return mySession == boardSessionId
	end

	local manualScreen
	local grindScreen

	local deck = skateboard:WaitForChild("Deck")
	local seat = skateboard:WaitForChild("VehicleSeat")
	local chassis = skateboard.Chassis

	local backLeft = skateboard.BackLeft
	local backRight = skateboard.BackRight
	local frontLeft = skateboard.FrontLeft
	local frontRight = skateboard.FrontRight

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { skateboard, char }

	local riding = skateboard:WaitForChild("Riding")

	local inOllie = false
	local tricksDebounce = true
	local isMoving = false
	local canPush = true
	local airDebounce = true
	local ollieDebounce = true
	local ollieTimes = 0

	local steer = 0
	local turnSpeed = 100
	local ollieHeight
	local specificRagdollDebounce = true
	local speed = 30

	local advancedTrick = false

	local Manual, NoseManual

	local canNoseManual = false
	local canManual = false
	local manualExecuted = false
	local manualDebounce = true
	local canManualLoop = true
	local MANUAL_DIRECTION = false

	local shitassDebounce = true
	local rightDirection = false

	local comboTimer = 0
	local maxTimer = 1
	local combo = 0
	local decoyCombo = 0
	local comboMultiplier = 0
	local comboActive = false
	local displayingComboDebounce = false
	local comboHistory = {}

	local ifVert = false
	local canAirCheck = true

	local canGrindLoop = true
	local canGrind = false
	local flowGrind = false
	local isGrinding = false
	local grindRail = nil
	local grindConnection = nil
	local grindSign = 1
	local grindDir = nil
	local GRIND_DIRECTION = false
	local GRIND_SPEED = 30
	local GRIND_FALL_OFF_DISTANCE = 4

	local canBSSlide = false
	local canFSSlide = false

	local GRIND_EXIT_SIDE = 1
	local GRIND_EXIT_SPEED = 20
	local GRIND_EXIT_HEIGHT = 10

	local grindDebounce = true
	local GRIND_REATTACH_COOLDOWN = 0.5

	local flowGrindConnection = nil
	local FLOW_GRIND_MAX_DISTANCE = 6
	local FLOW_GRIND_MAX_TIME = 0.4

	local function StartFlowGrindWindow()
		if flowGrindConnection then
			flowGrindConnection:Disconnect()
			flowGrindConnection = nil
		end

		flowGrind = true
		local startPos = chassis.Position
		local elapsed = 0

		flowGrindConnection = RS.Heartbeat:Connect(function(dt)
			elapsed += dt
			local traveled = (chassis.Position - startPos).Magnitude

			if not stillActive() or isGrinding or traveled >= FLOW_GRIND_MAX_DISTANCE or elapsed >= FLOW_GRIND_MAX_TIME then
				flowGrind = false
				if flowGrindConnection then
					flowGrindConnection:Disconnect()
					flowGrindConnection = nil
				end
			end
		end)
	end

	local REALMOVEFORWARD

	local comboConnection = nil

	local function vertCheck()
		if not stillActive() then return end
		if not riding.Value then return end
		if not airDebounce then return end

		airDebounce = true
		local origin = chassis.Position
		local direction = Vector3.new(0, -3, 0)
		local result = workspace:Raycast(origin, direction, rayParams)

		if result and result.Instance and result.Instance.Name == "Vert" then
			print("VERT FOUND")
			speed = 100
		else
			speed = 30
		end
	end


	local defaultPosition = feedbackGui:WaitForChild("Fixed").Position
	local function playFeedback(imageLabel)
		local goal = imageLabel.Position + UDim2.new(0, 0, (imageLabel.Position.Y.Scale * -.5), 0)

		imageLabel.Position = defaultPosition
		imageLabel.ImageTransparency = 0

		task.wait()
		local connect
		connect = RS.Heartbeat:Connect(function(dt)
			local transparency = .8 * dt

			imageLabel.Position = imageLabel.Position:Lerp(goal, .01)
			imageLabel.ImageTransparency += transparency

			if imageLabel.ImageTransparency >= 1 or not riding.Value then
				connect:Disconnect()

				imageLabel.ImageTransparency = 1
				imageLabel.Position = defaultPosition
			end
		end)
	end

	local feedBADDebounce = true
	local function playSPECIFICALLYBADFeedback(imageLabel)
		if not feedBADDebounce then return end
		feedBADDebounce = false

		local goal = imageLabel.Position + UDim2.new(0, 0, (imageLabel.Position.Y.Scale * -.5), 0)

		imageLabel.Position = defaultPosition
		imageLabel.ImageTransparency = 0

		if imageLabel.Position ~= defaultPosition and imageLabel.ImageTransparency ~= 0 then return end

		task.wait()
		local connect
		connect = RS.Heartbeat:Connect(function(dt)
			local transparency = .8 * dt

			imageLabel.Position = imageLabel.Position:Lerp(goal, .1)
			imageLabel.ImageTransparency += transparency

			if imageLabel.ImageTransparency >= 1 then
				connect:Disconnect()

				imageLabel.ImageTransparency = 1
				imageLabel.Position = defaultPosition
				feedBADDebounce = true
			end
		end)
	end

	local function ragdollProcess()
		task.spawn(function() ragdollModule:Execute(char, skateboard) end)
		combo = 0
		comboMultiplier = 0
		decoyCombo = 0

		scoreLabel.Text = decoyCombo
		comboLabel.Text = ""
		tricksLabel.Text = ""
		comboHistory = {}

		playSPECIFICALLYBADFeedback(badFeedback[math.random(1, #badFeedback)])

		while completeSFX.IsPlaying or countingSFX.IsPlaying do
			completeSFX:Stop()
			countingSFX:Stop()
		end
	end

	local function airCheck()
		if not stillActive() then return end
		if not riding.Value then return end
		if not airDebounce then return end

		airDebounce = true
		local origin = chassis.Position
		local direction = Vector3.new(0, -2, 0)
		local result = workspace:Raycast(origin, direction, rayParams)

		if result and result.Instance then
			inOllie = true
			manualDebounce = false
			ollieDebounce = false
			airDebounce = false
			tricksDebounce = true
		else
			manualDebounce = true
			ollieDebounce = true
			airDebounce = true
			tricksDebounce = false
			inOllie = false
		end
	end

	local function startComboTimer()
		if comboConnection then return end
		comboConnection = RS.Heartbeat:Connect(function(dt)
			if comboActive then
				comboTimer -= dt
				if comboTimer <= 0 then
					comboActive = false
					comboConnection:Disconnect()

					combo = 0
					comboMultiplier = 0
					comboLabel.Text = ""
					tricksLabel.Text = ""
					comboConnection = nil
					comboHistory = {}
				end
			end
		end)
	end

	local function scoreCounter()
		if isGrinding or canManual then return end

		local goalCombo = combo * comboMultiplier
		if decoyCombo == goalCombo then countingSFX:Stop() countingSFX.Looped = false end
		local defaultSize = scoreLabel.Size

		task.spawn(function()
			while decoyCombo < goalCombo and riding.Value do

				if decoyCombo == goalCombo then countingSFX:Stop() countingSFX.Looped = false end

				decoyCombo += 1
				scoreLabel.Text = decoyCombo

				scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

				if not comboActive then

					decoyCombo = goalCombo
					scoreLabel.Text = decoyCombo

					completeSFX:Play()

					scoreLabel.TextColor3 = Color3.fromRGB(65, 157, 255)
					break
				end

				task.wait(.001 - (1000 / comboMultiplier))
			end
			scoreLabel.Size = defaultSize
			scoreLabel.TextColor3 = Color3.fromRGB(65, 157, 255)
		end)
	end

	local function trackCombo(trickName, isItATrick, HardTrick)
		if not comboActive then decoyCombo = 0 comboMultiplier = 0 end

		local HttpService = game:GetService("HttpService")
		if not flowGrind then
			table.insert(comboHistory, trickName)
		end
		local cleaned = HttpService:JSONEncode(comboHistory):gsub('["%[%]{}]', " ")

		comboActive = true
		comboTimer = maxTimer
		tricksLabel.Text = cleaned

		if isItATrick == 3 then
			if HardTrick then
				comboMultiplier += 1
				combo += 100
				comboLabel.Text = combo.. " x ".. comboMultiplier

				playFeedback(GREATFeedback[math.random(1, #GREATFeedback)])

				task.wait(.5)

			elseif not HardTrick then
				comboMultiplier += 1
				combo += 50
				comboLabel.Text = combo.. " x ".. comboMultiplier

				playFeedback(goodFeedback[math.random(1, #goodFeedback)])

				task.wait(.5)
			end

		elseif isItATrick == 2 then
			comboMultiplier += 1
			playFeedback(goodFeedback[math.random(1, #goodFeedback)])
			while canManualLoop do
				combo += 1
				comboLabel.Text = combo.. " x ".. comboMultiplier
				comboTimer = maxTimer
				task.wait(.1)
			end
		elseif isItATrick == 1 then
			comboMultiplier += 1
			playFeedback(goodFeedback[math.random(1, #goodFeedback)])
			while canGrindLoop do
				combo += 3
				comboLabel.Text = combo.. " x ".. comboMultiplier
				comboTimer = maxTimer

				task.wait(.1)
			end
		end

		scoreCounter()

		startComboTimer()
	end

	local function stopState()
		isMoving = false
		canPush = true
		airDebounce = true
		canGrind = false
		isGrinding = true
		inOllie = false
		canManual = false
		canGrindLoop = false
		canManualLoop = false

		ollieTrack:Stop()
		idleTrack:Stop()
		pushTrack:Stop()
		fiftyfiftyGrindTrack:Stop()
	end

	local function EndGrind(continueRolling, fakeDeck)
		if not isGrinding then return end
		isGrinding = false
		canGrindLoop = false

		if grindConnection then
			grindConnection:Disconnect()
			grindConnection = nil
		end
		grindRail = nil

		canPush = true
		isMoving = false

		canNoseManual = false
		canManual = false

		StartFlowGrindWindow()

		task.delay(.05, function()
			if stillActive() and not isGrinding then
				fiftyfiftyGrindTrack:Stop()
				BSBoardSlideTrack:Stop()
				FSBoardSlideTrack:Stop()
				idleTrack:Play()
			end
		end)

		task.wait(.05)
		REALMOVEFORWARD()
	end

	local function StartGrind(rail, isFlow, trackAnim, trickName, rotation)
		if isGrinding then return end

		if not flowGrind then
			stopState()
			task.wait(.015)
			grindScreen()

			trackAnim:Play()
			ollieTrack:Stop()
			pushTrack:Stop()
		end

		local genuineRotation
		if trackAnim == BSBoardSlideTrack or trackAnim == FSBoardSlideTrack then
			genuineRotation = 90
		else
			genuineRotation = 0
		end

		skateboard:WaitForChild("Trick Nailed "):Play()

		local fakeDeck
		if skateboard:FindFirstChild("Fake Deck") then
			fakeDeck = skateboard:FindFirstChild("Fake Deck")
		else
			fakeDeck = deck:Clone()
			fakeDeck.Parent = skateboard
			fakeDeck.CFrame = deck.CFrame
			fakeDeck.Name = "Fake Deck"
			fakeDeck.Transparency = 0
			fakeDeck.Anchored = true

			for _, v in ipairs(fakeDeck:GetChildren()) do
				if not v:IsA("SpecialMesh") then
					v:Destroy()
				end
			end
		end

		deck.Transparency = 1

		isGrinding = true
		grindRail = rail
		canGrindLoop = true

		local axis = RailAxis(rail)
		local facing = -chassis.CFrame.LookVector

		grindSign = (facing:Dot(axis) >= 0) and 1 or -1
		grindDir = axis * grindSign

		task.spawn(function()
			trackCombo(trickName, 1)
		end)

		grindConnection = TrackConnection(RS.Heartbeat:Connect(function(dt)
			fakeDeck.CFrame = deck.CFrame * CFrame.Angles(0, math.rad(genuineRotation), 0)

			if not stillActive() or not riding.Value then
				EndGrind(false, fakeDeck)

				return
			end

			if not grindRail or not grindRail.Parent then
				EndGrind(true, fakeDeck)

				return
			end

			local point, t = ClosestPointOnRail(grindRail, chassis.Position)

			local lateralOffset = chassis.Position - point

			if lateralOffset.Magnitude > GRIND_FALL_OFF_DISTANCE  and not isFlow then
				EndGrind(false, fakeDeck)

				return
			end

			if t <= 0.001 or t >= 0.999 and not isFlow  then
				EndGrind(true, fakeDeck)

				return
			end

			canManual = false

			local moveAxis = RailAxis(grindRail)
			local moveDir = moveAxis * grindSign
			grindDir = moveDir

			local moveDistance = GRIND_SPEED * dt
			local targetPoint = point + moveDir * moveDistance

			targetPoint += Vector3.new(0, 2, 0)

			local targetCFrame = CFrame.lookAt(
				targetPoint,
				targetPoint - moveDir
			)

			chassis.CFrame = targetCFrame

			chassis.AssemblyLinearVelocity = moveDir * GRIND_SPEED
			chassis.CFrame = chassis.CFrame:Lerp(targetCFrame, math.clamp(dt * 20, 0, 1))
			chassis.AssemblyAngularVelocity = Vector3.zero

			fakeDeck.CFrame = deck.CFrame * CFrame.Angles(0, math.rad(genuineRotation), 0)
		end))
	end

	local function OllieOffGrind(direction)
		if not isGrinding then return end
		isGrinding = false
		canGrindLoop = false

		canManual = false
		canNoseManual = false

		deck.Transparency = 0

		fiftyfiftyGrindTrack:Stop()
		BSBoardSlideTrack:Stop()

		startComboTimer()

		grindDebounce = false
		task.delay(GRIND_REATTACH_COOLDOWN, function()
			if stillActive() then
				grindDebounce = true
			end
		end)

		if grindConnection then
			grindConnection:Disconnect()
			grindConnection = nil
		end
		grindRail = nil

		local forwardDir = grindDir or (chassis.CFrame.LookVector * -1)

		local sideways = forwardDir:Cross(Vector3.new(0, 1, 0))
		if sideways.Magnitude > 0.001 then
			sideways = sideways.Unit
		else
			sideways = chassis.CFrame.RightVector
		end

		local sign = (sideways:Dot(direction) >= 0) and 1 or -1
		local sideDir = sideways * sign * GRIND_EXIT_SIDE

		chassis.CFrame = CFrame.lookAt(chassis.Position, chassis.Position - forwardDir, Vector3.new(0, 1, 0))
		chassis.AssemblyAngularVelocity = Vector3.zero

		chassis.AssemblyLinearVelocity = (forwardDir * GRIND_EXIT_SPEED)
			+ (sideDir * GRIND_EXIT_SPEED)
			+ (Vector3.new(0, 1, 0) * GRIND_EXIT_HEIGHT)

		ollieTrack.TimePosition = .3
		ollieDebounce = false
		airDebounce = false

		for i,v in animTable do
			v:Stop()
		end

		task.wait(.25)
		task.spawn(REALMOVEFORWARD())
	end

	local function rotationCheck()
		if isGrinding or vertCheck() or flowGrind then return end

		local up = chassis.CFrame.UpVector
		local dot = up:Dot(Vector3.new(0, 1, 0))

		if dot < .6 and specificRagdollDebounce and riding.Value then
			ragdollProcess()
			specificRagdollDebounce = false
		else
			specificRagdollDebounce = true
		end
	end

	local function onBoard(_, new)
		if new == Enum.HumanoidStateType.Seated then
			valueEvent:FireServer(true)
			idleTrack:Play()
			riding.Value = true
			skateboard.Parent = char

			chassis.CanCollide = true
		else
			valueEvent:FireServer(false)
			for _, track in ipairs(animTable) do
				track:Stop()
			end

			chassis.CanCollide = false
			skateboard.Parent = workspace
			riding.Value = false
			ollieHeight = 55
			canPush = true

			canGrindLoop = false
			canManualLoop = false

			canManual = false
			manualExecuted = false
			EndGrind(false)
		end
	end

	manualScreen = function(regular, gui)
		gui.Enabled = true
		skateboard:WaitForChild("Trick Nailed "):Play()

		local percent = .5

		local bar = gui.Bar
		local marker = bar.Marker

		marker.AnchorPoint = Vector2.new(0.5, -.1)
		marker.Position = UDim2.new(.5, 0, -.1, 0)

		task.spawn(function()
			while stillActive() and not inOllie and riding.Value do
				local percentSpeed = .01 + (comboMultiplier / 1000)

				if MANUAL_DIRECTION and riding.Value then
					if regular then
						percent = percent - percentSpeed
					elseif not regular then
						percent = percent + percentSpeed
					end
				elseif not MANUAL_DIRECTION and riding.Value then
					if regular then
						percent = percent + percentSpeed
					elseif not regular then
						percent = percent - percentSpeed
					end
				else
					canManual = false
					canNoseManual = false
					gui.Enabled = false
					break
				end

				marker.AnchorPoint = Vector2.new(0.5, 0.5)
				if regular then
					marker.Position = marker.Position:Lerp(UDim2.new(percent, 0, .8, 0), .1)
				elseif not regular then
					marker.Position = marker.Position:Lerp(UDim2.new(percent, 0, .2, 0), .1)
				end

				if percent <= 0 then
					canManual = false
					canNoseManual = false
					gui.Enabled = false
					ragdollProcess()
					break
				elseif percent >= 1 then
					scoreLabel.Text = combo * comboMultiplier
					completeSFX:Play()

					task.wait()

					comboActive = false
					combo = 0
					comboMultiplier = 0
					comboHistory = {}
					comboLabel.Text = ""
					tricksLabel.Text = game:GetService("HttpService"):JSONEncode(comboHistory):gsub('["%[%]{}]', " ")

					canManual = false
					canNoseManual = false
					gui.Enabled = false
					break
				end

				task.wait(.01)
			end

			canManual = false
			canNoseManual = false
			gui.Enabled = false
		end)
	end

	grindScreen = function()
		grindGui.Enabled = true

		local percent = .5

		local bar = grindGui.Bar
		local marker = bar.Marker

		marker.AnchorPoint = Vector2.new(0.5, 0.2)
		marker.Position = UDim2.new(.5, 0, .2, 0)

		task.wait(.05)

		task.spawn(function()
			while stillActive() do
				local percentSpeed = .01 + (comboMultiplier / 1000)

				local randomizer = math.random(1, 5)
				if not GRIND_DIRECTION and riding.Value then
					percent = percent - percentSpeed
				elseif GRIND_DIRECTION and riding.Value then
					percent = percent + percentSpeed
				else
					canGrind = false
					grindGui.Enabled = false
					break
				end

				marker.AnchorPoint = Vector2.new(0.5, 0.5)
				marker.Position = marker.Position:Lerp(UDim2.new(percent, 0, .2, 0), .1)

				task.wait(.01)

				if not isGrinding and not flowGrind then
					canGrind = false
					grindGui.Enabled = false
					break
				elseif percent <= 0 and isGrinding then
					canGrind = false
					grindGui.Enabled = false
					stopState()
					ragdollProcess()
					break
				elseif percent >= 1 and isGrinding then
					canGrind = false
					grindGui.Enabled = false
					stopState()
					ragdollProcess()
					break
				end
			end
		end)
	end

	local function speedCheck()
	end

	function REALMOVEFORWARD()
		ollieHeight = 55
		isMoving = true
		canPush = false
		airDebounce = true
		ollieDebounce = true

		idleTrack:Play()

		deck.Transparency = 0

		if skateboard:FindFirstChild("Fake Deck") then
			skateboard:FindFirstChild("Fake Deck"):Destroy()
		end

		task.spawn(function()
			while stillActive() and isMoving and not canPush do
				if not pushTrack.IsPlaying and riding.Value then
					pushTrack:Play()
				end
				pushTrack.Stopped:Wait()
				task.wait(math.random(4, 8))
			end
		end)

		task.wait(.2)

		task.spawn(function()
			while stillActive() and isMoving and not canPush do
				if not isGrinding then
					chassis.AssemblyLinearVelocity = chassis.AssemblyLinearVelocity:Lerp((-chassis.CFrame.LookVector * speed), .35)
				end
				task.wait(.025)
			end
		end)

		task.spawn(function()
			while stillActive() and isMoving and not canPush do
				speedCheck()
				task.wait(.5)
			end
		end)
	end

	local function forward(input, gameProcessed)
		if gameProcessed then return end
		if isGrinding then return end

		if input.KeyCode == Enum.KeyCode.W then
			canManual = true
			if riding.Value and canPush and not canNoseManual then
				REALMOVEFORWARD()
			elseif canNoseManual and not manualExecuted and manualDebounce and not inOllie and riding.Value then
				NoseManual()
			end
		end
	end

	Manual = function()
		manualTrack:Play()
		manualDebounce = false
		manualExecuted = true

		ollieDebounce = true
		airDebounce = true

		canManualLoop = true

		task.spawn(function() REALMOVEFORWARD() end)

		manualScreen(true, manualGui)

		local fakeDeck = deck:Clone()
		fakeDeck.Parent = skateboard
		fakeDeck.CFrame = deck.CFrame
		for _, v in ipairs(fakeDeck:GetChildren()) do
			if not v:IsA("SpecialMesh") then
				v:Destroy()
			end
		end
		deck.Transparency = 1

		task.spawn(function() trackCombo("Manual", 2) end)

		local connection
		connection = TrackConnection(RS.Heartbeat:Connect(function()
			local startCF = deck.CFrame
			fakeDeck.CFrame = startCF * CFrame.Angles(math.rad(-10), 0, 0)

			if not canManual or not stillActive() or inOllie then
				manualExecuted = false
				manualDebounce = true
				canManualLoop = false

				connection:Disconnect()

				manualTrack:Stop()
				deck.Transparency = 0
				if fakeDeck.Parent then
					fakeDeck:Destroy()
				end
			end
		end))
	end

	NoseManual = function()
		noseManualTrack:Play()
		manualDebounce = false
		manualExecuted = true

		ollieDebounce = true
		airDebounce = true

		canManualLoop = true

		task.spawn(function() REALMOVEFORWARD() end)

		manualScreen(false, noseManualGui)

		local fakeDeck = deck:Clone()
		fakeDeck.Parent = skateboard
		fakeDeck.CFrame = deck.CFrame
		for _, v in ipairs(fakeDeck:GetChildren()) do
			if not v:IsA("SpecialMesh") then
				v:Destroy()
			end
		end
		deck.Transparency = 1

		task.spawn(function() trackCombo("Nose Manual", 2) end)

		local connection
		connection = TrackConnection(RS.Heartbeat:Connect(function()
			local startCF = deck.CFrame
			fakeDeck.CFrame = startCF * CFrame.Angles(math.rad(10), 0, 0)

			if not canNoseManual or not stillActive() or inOllie then
				manualExecuted = false
				manualDebounce = true
				canManualLoop = false

				connection:Disconnect()

				noseManualTrack:Stop()
				deck.Transparency = 0
				if fakeDeck.Parent then
					fakeDeck:Destroy()
				end
			end
		end))
	end

	local function isManualPossible(input)
		if input.KeyCode == Enum.KeyCode.S and not canPush and not inOllie then
			canNoseManual = true
			if canManual and not manualExecuted and manualDebounce and not inOllie and riding.Value then
				Manual()
			end
		end
	end

	local function behind(input, gameProcessed)
		if gameProcessed then return end
		if isGrinding then return end

		if input.KeyCode == Enum.KeyCode.S and not canPush and not inOllie and not canManual then
			canManual = false
			canNoseManual = false
			canPush = true
			isMoving = false
			chassis.Anchored = true
			chassis.AssemblyLinearVelocity = Vector3.zero
			pushTrack:Stop()
			task.wait(.01)
			chassis.Anchored = false
			task.wait(.01)
			chassis.AssemblyLinearVelocity = Vector3.zero
			ollieHeight = 55
			ollieDebounce = true
		end
	end

	local function CancelPendingManualTrick(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.W and not manualExecuted and manualDebounce and riding.Value then
			canManual = false
			manualDebounce = true
		end
	end

	local function CheckForRail()
		if not stillActive() then return end
		if not riding.Value then return end
		if isGrinding then return end
		if not grindDebounce then return end

		local result = workspace:Raycast(chassis.Position, -chassis.CFrame.UpVector.Unit * 50, rayParams)
		if result and IsGrindableRail(result.Instance) and canGrind and riding.Value then
			if not canBSSlide and not canFSSlide then
				StartGrind(result.Instance, false, fiftyfiftyGrindTrack, "FS 50 - 50", 0)
			elseif canBSSlide and not canFSSlide then
				StartGrind(result.Instance, false, BSBoardSlideTrack, "BS BoardSlide", 90)
			elseif not canBSSlide and canFSSlide then
				StartGrind(result.Instance, false, FSBoardSlideTrack, "FS BoardSlide", 90)
			end
		elseif result and IsGrindableRail(result.Instance) and flowGrind and riding.Value then
			if not canBSSlide and not canFSSlide then
				StartGrind(result.Instance, false, fiftyfiftyGrindTrack, nil, 0)
			elseif canBSSlide and not canFSSlide then
				StartGrind(result.Instance, false, BSBoardSlideTrack, nil, 90)
			elseif not canBSSlide and canFSSlide then
				StartGrind(result.Instance, false, FSBoardSlideTrack, nil, 90)
			end
		end
	end

	local function ManualDirectionInput(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.W and not inOllie and riding.Value then
			MANUAL_DIRECTION = false
		end
		if input.KeyCode == Enum.KeyCode.S and not inOllie and riding.Value then
			MANUAL_DIRECTION = true
		end

		if input.KeyCode == Enum.KeyCode.D and riding.Value then
			GRIND_DIRECTION = true
		end

		if input.KeyCode == Enum.KeyCode.A and riding.Value then
			GRIND_DIRECTION = false
		end
	end

	local function differentGrinds0(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.A and riding.Value and not isGrinding and not flowGrind and not canGrind then
			canBSSlide = true
			canFSSlide = false
		end

		if input.KeyCode == Enum.KeyCode.D and riding.Value and not isGrinding and not flowGrind and not canGrind then
			canFSSlide = true
			canBSSlide = false
		end
	end

	local function differentGrinds1(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.A and riding.Value and not isGrinding and not flowGrind and not canGrind then
			canBSSlide = false
		end

		if input.KeyCode == Enum.KeyCode.D and riding.Value and not isGrinding and not flowGrind and not canGrind then
			canFSSlide = false
		end
	end

	local function OllieKneel(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.D and riding.Value and isGrinding then
			rightDirection = true
			print("Direction: ", rightDirection)
		elseif input.KeyCode == Enum.KeyCode.A and riding.Value and isGrinding then
			rightDirection = false
			print("Direction: ", rightDirection)
		end

		if input.KeyCode == Enum.KeyCode.Seven and ollieDebounce and riding.Value then
			if not manualDebounce then canPush = false isMoving = false end
			ollieTrack:Stop()
			task.wait()
			shitassDebounce = false
			ollieTrack:Play()
			ollieDebounce = true
			airDebounce = true
			isMoving = false
			inOllie = false
			pushTrack:Stop()
			task.wait(.19)
			ollieTrack:AdjustSpeed(0)
		end
	end

	local function Ollie()
		skateboard:WaitForChild("Ollie Pop"):Play()

		ollieTrack:Stop()
		ollieTrack:Play()
		ollieTrack.TimePosition = .3

		shitassDebounce = true
		ollieDebounce = false
		isMoving = true
		tricksDebounce = true
		canPush = false
		airDebounce = false
		deck.Transparency = 0

		canManual = false
		canNoseManual = false
		manualExecuted = false
		manualDebounce = true
		manualTrack:Stop()

		task.wait(.06)

		chassis.AssemblyLinearVelocity = (chassis.CFrame.UpVector.Unit * 50) + (-chassis.CFrame.LookVector * 20)
		ollieTrack:AdjustSpeed(1)

		inOllie = true

		task.spawn(function() REALMOVEFORWARD() end)

		task.wait(.3)

		ollieTrack:AdjustSpeed(1)
		tricksDebounce = false

		task.wait(.2)
		ollieTrack:AdjustSpeed(1)
		tricksDebounce = false
		manualDebounce = true
		ollieDebounce = true
		airDebounce = true
		tricksDebounce = false
		task.wait(.2)
		inOllie = false
	end

	local function OllieJump(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.Seven and ollieDebounce and airDebounce and riding.Value and not isGrinding then
			Ollie()
		elseif input.KeyCode == Enum.KeyCode.Seven and riding.Value and isGrinding and rightDirection then
			OllieOffGrind(-chassis.CFrame.RightVector)
			return
		elseif input.KeyCode == Enum.KeyCode.Seven and riding.Value and isGrinding and not rightDirection then
			OllieOffGrind(chassis.CFrame.RightVector)
			return
		end

	end

	local function PerformTrick(tracks, rotationFn, totalRadians, trickName, trickSpeed)
		tricksDebounce = false
		canManual = false
		manualExecuted = false
		manualTrack:Stop()

		for _, track in ipairs(tracks) do
			track:Play()
		end

		local fakeDeck = deck:Clone()
		fakeDeck.Parent = skateboard
		fakeDeck.CFrame = deck.CFrame
		for _, v in ipairs(fakeDeck:GetChildren()) do
			if not v:IsA("SpecialMesh") then
				v:Destroy()
			end
		end
		deck.Transparency = 1

		local rotation = 0
		local connection
		skateboard:WaitForChild("Trick Nailed "):Play()

		task.spawn(function() trackCombo(trickName, 3, false) end)

		connection = TrackConnection(RS.Heartbeat:Connect(function(dt)
			local startCF = deck.CFrame
			rotation += math.rad(trickSpeed) * dt
			fakeDeck.CFrame = fakeDeck.CFrame:Lerp(startCF * rotationFn(rotation), .7)

			if rotation >= totalRadians or not stillActive() then
				connection:Disconnect()
				manualDebounce = true
				deck.Transparency = 0
				if fakeDeck.Parent then
					fakeDeck:Destroy()
				end
			end
		end))

		task.wait(0.5)
		tricksDebounce = true
		inOllie = false
	end

	local function PerformTrickADVANCED(tracks, firstRotationFn, secondRotationFn, firsttotalRadians, secondTotalRadians, trickName, trickSpeed)
		tricksDebounce = false
		canManual = false
		manualExecuted = false
		manualTrack:Stop()

		task.spawn(function()
			for _, track in ipairs(tracks) do
				track:Play()
			end
		end)

		local fakeDeck = deck:Clone()
		fakeDeck.Parent = skateboard
		fakeDeck.CFrame = deck.CFrame
		fakeDeck.Anchored = true
		for _, v in ipairs(fakeDeck:GetChildren()) do
			if not v:IsA("SpecialMesh") then
				v:Destroy()
			end
		end
		deck.Transparency = 1

		local firstRotation = 0
		local secondRotation = 0
		local otherConnection
		skateboard:WaitForChild("Trick Nailed "):Play()

		task.spawn(function() trackCombo(trickName, 3, true) end)

		local anotherTrickSpeedVariable = 1

		fakeDeck.CFrame = CFrame.Angles(math.rad(45), 0, 0)

		task.spawn(function()
			otherConnection = TrackConnection(RS.Heartbeat:Connect(function(dt)
				local startCF = deck.CFrame
				firstRotation += math.rad(500) * dt

				if firstRotation < math.rad(60) then
					anotherTrickSpeedVariable = 0
				else
					anotherTrickSpeedVariable = trickSpeed + 200
				end

				secondRotation += math.rad(anotherTrickSpeedVariable) * dt
				fakeDeck.CFrame = (startCF * firstRotationFn(firstRotation)) * secondRotationFn(secondRotation)

				if secondRotation >= secondTotalRadians then
					otherConnection:Disconnect()
					manualDebounce = true
					deck.Transparency = 0
					if fakeDeck.Parent then
						fakeDeck:Destroy()
					end
				end

				if not inOllie and secondRotation < secondTotalRadians then
					otherConnection:Disconnect()
					manualDebounce = true
					deck.Transparency = 0
					ragdollProcess()
					if fakeDeck.Parent then
						fakeDeck:Destroy()
					end
				end
			end))
		end)

		task.wait(0.5)
		tricksDebounce = true
		inOllie = false
	end

	local function PopShuvIt()
		PerformTrick({ popShuvTrack }, function(r) return CFrame.Angles(0, -r, 0) end, math.rad(180), "BS Pop Shuv It", 900)
	end

	local function KickFlip()
		PerformTrick({ kickflipTrack }, function(r) return CFrame.Angles(0, 0, -r) end, math.rad(360), "KickFlip", 900)
	end

	local function HeelFlip()
		PerformTrick({ heelflipTrack }, function(r) return CFrame.Angles(0, 0, r) end, math.rad(360), "HeelFlip", 900)
	end

	local function FrontShuvIt()
		PerformTrick({ frontShuvTrack}, function(r) return CFrame.Angles(0, r, 0) end, math.rad(180), "FS Pop Shuv It", 900)
	end

	local function VarialKickFlip()
		PerformTrickADVANCED(
			{ kickflipTrack },

			function(r) return CFrame.Angles(0, -r, 0) end,
			function(r) return CFrame.Angles(0, 0, -r) end,

			math.rad(180),
			math.rad(360),

			"Varial KickFlip",
			750
		)
	end

	local function VarialHeelFlip()
		PerformTrickADVANCED(
			{ popShuvTrack, heelflipTrack },

			function(r) return CFrame.Angles(0, -r, 0) end,
			function(r) return CFrame.Angles(0, 0, r) end,

			math.rad(180),
			math.rad(360),

			"Varial HeelFlip",
			750
		)
	end

	local function TreFlip()
		PerformTrickADVANCED(
			{ frontShuvTrack, kickflipTrack },

			function(r) return CFrame.Angles(0, -r, 0) end,
			function(r) return CFrame.Angles(0, 0, -r) end,

			math.rad(360),
			math.rad(360),

			"TreFlip",
			750
		)
	end

	local function LaserFlip()
		PerformTrickADVANCED(
			{ popShuvTrack, heelflipTrack },

			function(r) return CFrame.Angles(0, r, 0) end,
			function(r) return CFrame.Angles(0, 0, r) end,

			math.rad(360),
			math.rad(360),

			"LaserFlip",
			750
		)
	end


	local function Tricks(input, gameProcessed)
		if gameProcessed then return end
		if isGrinding then return end
		if not (inOllie and riding.Value) then return end

		local trickFor = {
			[Enum.KeyCode.A] = KickFlip,
			[Enum.KeyCode.W] = FrontShuvIt,
			[Enum.KeyCode.S] = PopShuvIt,
			[Enum.KeyCode.D] = HeelFlip,
		}

		local hardtrickFor = {
			[Enum.KeyCode.A] = VarialKickFlip,
			[Enum.KeyCode.D] = VarialHeelFlip,
			[Enum.KeyCode.Q] = TreFlip,
			[Enum.KeyCode.E] = LaserFlip
		}

		local trick = trickFor[input.KeyCode]
		local hardtrick = hardtrickFor[input.KeyCode]
		if not trick and not hardtrick then return end

		if tricksDebounce and not advancedTrick then
			trick()
		elseif tricksDebounce and advancedTrick then
			hardtrick()
		end
	end

	TrackConnection(userInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.A and riding.Value then
			steer = 1
		elseif input.KeyCode == Enum.KeyCode.D and riding.Value then
			steer = -1
		end
	end))

	TrackConnection(userInputService.InputEnded:Connect(function(input)
		if (input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D) and riding.Value then
			steer = 0
		end
	end))

	TrackConnection(RS.RenderStepped:Connect(function(dt)
		if not isGrinding and steer ~= 0 and riding.Value or not shitassDebounce then
			local cf = chassis:GetPivot()
			chassis:PivotTo(cf * CFrame.Angles(0, math.rad(turnSpeed * steer * dt), 0))
		end
	end))

	TrackConnection(RS.Heartbeat:Connect(CheckForRail))

	task.spawn(function()
		while stillActive() do
			if riding.Value then
				rotationCheck()
				vertCheck()
			end
			task.wait(.5)
		end
	end)

	userInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.Nine and riding.Value then
			canGrind = true
			canManual = false
		end

		if input.KeyCode == Enum.KeyCode.Eight and riding.Value then
			advancedTrick = true
		end
	end)

	userInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.Nine and riding.Value then
			canGrind = false
		end

		if input.KeyCode == Enum.KeyCode.Eight and riding.Value then
			advancedTrick = false
		end
	end)

	TrackConnection(humanoid.StateChanged:Connect(onBoard))
	TrackConnection(userInputService.InputBegan:Connect(ManualDirectionInput))
	TrackConnection(userInputService.InputBegan:Connect(forward))
	TrackConnection(userInputService.InputEnded:Connect(CancelPendingManualTrick))
	TrackConnection(userInputService.InputBegan:Connect(isManualPossible))
	TrackConnection(userInputService.InputBegan:Connect(differentGrinds0))
	TrackConnection(userInputService.InputEnded:Connect(differentGrinds1))
	TrackConnection(userInputService.InputEnded:Connect(behind))
	TrackConnection(userInputService.InputBegan:Connect(OllieKneel))
	TrackConnection(userInputService.InputEnded:Connect(OllieJump))
	TrackConnection(userInputService.InputBegan:Connect(Tricks))
end)
