ESX = nil
local HasAlreadyEnteredMarker, onDuty, OnJob, Done = false, false, false, false
local LastZone, CurrentAction, CurrentActionMsg, BlipCloakRoom, BlipVehicle, BlipVehicleDeleter
local CurrentActionData, Blips = {}, {}

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(10)
	end

	while ESX.GetPlayerData().job == nil do
		Citizen.Wait(100)
	end

	ESX.PlayerData = ESX.GetPlayerData()
	CreateBlip()
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
	ESX.PlayerData = xPlayer
	CreateBlip()
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	ESX.PlayerData.job = job
	onDuty = false
	CreateBlip()
end)

function SelectPool()
	local index = GetRandomIntInRange(1, #Config.Pool)

	for k,v in pairs(Config.Zones) do
		if v.Pos.x == Config.Pool[index].x and v.Pos.y == Config.Pool[index].y and v.Pos.z == Config.Pool[index].z then
			return k
		end
	end
end

function StartNPCJob()
	NPCTargetPool = SelectPool()
	local zone = Config.Zones[NPCTargetPool]

	Blips['NPCTargetPool'] = AddBlipForCoord(zone.Pos.x, zone.Pos.y, zone.Pos.z)
	SetBlipRoute(Blips['NPCTargetPool'], true)
	ESX.ShowNotification(_U('GPS_info'))
	Done = true
end

function StopNPCJob(cancel)
	if Blips['NPCTargetPool'] ~= nil then
		RemoveBlip(Blips['NPCTargetPool'])
		Blips['NPCTargetPool'] = nil
	end

	OnJob = false

	if cancel then
		ESX.ShowNotification(_U('cancel_mission'))
	else
		TriggerServerEvent('esx_oceansalvage:GiveItem')
		StartNPCJob()
		Done = true
	end
end

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(10)

		if NPCTargetPool ~= nil then

			local playerPed = PlayerPedId()
			local coords = GetEntityCoords(playerPed)
			local zone = Config.Zones[NPCTargetPool]

			if GetDistanceBetweenCoords(coords, zone.Pos.x, zone.Pos.y, zone.Pos.z, true) < 3 then

				ESX.ShowHelpNotification(_U('pickup'))

				if IsControlJustReleased(1, 38) and ESX.PlayerData.job ~= nil then
					TaskStartScenarioInPlace(playerPed, 'WORLD_HUMAN_WELDING', 0, true)
					Citizen.Wait(17000)
					StopNPCJob()
					Citizen.Wait(3000)
					ClearPedTasksImmediately(playerPed)
					Done = false
				end
			end
		end
	end
end)

function CloakRoomMenu()

	local elements = {}

	if onDuty then
		table.insert(elements, {label = _U('end_service'), value = 'citizen_wear'})
	else
		table.insert(elements, {label = _U('take_service'), value = 'job_wear'})
	end

	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'cloakroom', {
		title = _U('locker_title'),
		align = 'top-left',
		elements = elements
	}, function(data, menu)

		if data.current.value == 'citizen_wear' then

			onDuty = false
			CreateBlip()
			menu.close()
			ESX.ShowNotification(_U('end_service_notif'))

			ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
				TriggerEvent('skinchanger:loadSkin', skin)
			end)

		elseif data.current.value == 'job_wear' then

			onDuty = true
			CreateBlip()
			menu.close()
			ESX.ShowNotification(_U('take_service_notif'))
			ESX.ShowNotification(_U('start_job'))
			setUniform(data.current.value)

		end

		CurrentAction = 'cloakroom_menu'
		CurrentActionMsg = Config.Zones.Cloakroom.hint
		CurrentActionData = {}
	end, function(data, menu)
		menu.close()

		CurrentAction = 'cloakroom_menu'
		CurrentActionMsg = Config.Zones.Cloakroom.hint
		CurrentActionData = {}
	end)

end

function VehicleMenu()

	local elements = {
		{label = Config.Vehicles.Truck.Label, value = Config.Vehicles.Truck}
	}

	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'spawn_vehicle', {
		title = _U('Vehicle_Menu_Title'),
		align = 'top-left',
		elements = elements
	}, function(data, menu)

		menu.close()
		local playerPed = PlayerPedId()
		local plateNum = math.random(1000, 9999)
		local platePrefix = Config.PlatePrefix

		ESX.Game.SpawnVehicle(data.current.value.Hash, Config.Zones.VehicleSpawnPoint.Pos, Config.Zones.VehicleSpawnPoint.Heading, function(vehicle)
			TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
			SetVehicleNumberPlateText(vehicle, platePrefix .. plateNum)

			local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))

			name = 'Véhicule de '..platePrefix
			TriggerServerEvent('esx_vehiclelock:registerkeyjob', name, plate, 'no')
		end)

	end, function(data, menu)
		menu.close()

		CurrentAction = 'vehiclespawn_menu'
		CurrentActionMsg = Config.Zones.VehicleSpawner.hint
		CurrentActionData = {}
	end)

end

AddEventHandler('esx_oceansalvage:hasEnteredMarker', function(zone)

	if zone == 'Cloakroom' then
		CurrentAction = 'cloakroom_menu'
		CurrentActionMsg = Config.Zones.Cloakroom.hint
		CurrentActionData = {}
	elseif zone == 'VehicleSpawner' then
		CurrentAction = 'vehiclespawn_menu'
		CurrentActionMsg = Config.Zones.VehicleSpawner.hint
		CurrentActionData = {}
	elseif zone == 'VehicleDeleter' then

		local playerPed = PlayerPedId()
		if IsPedInAnyVehicle(playerPed, false) then
			local vehicle = GetVehiclePedIsIn(playerPed, false)

			if GetPedInVehicleSeat(vehicle, -1) == playerPed then
				CurrentAction = 'delete_vehicle'
				CurrentActionMsg = Config.Zones.VehicleDeleter.hint
				CurrentActionData = {}
			end
		end

	elseif zone == 'Sale' then
		CurrentAction = 'sale'
		CurrentActionMsg = Config.Zones.Sale.hint
		CurrentActionData = {}
	end
end)

AddEventHandler('esx_oceansalvage:hasExitedMarker', function(zone)
	if zone == 'Sale' then
		TriggerServerEvent('esx_oceansalvage:stopSale')
	end

	CurrentAction = nil
	ESX.UI.Menu.CloseAll()
end)

function CreateBlip()
	if ESX.PlayerData.job ~= nil and ESX.PlayerData.job.name == Config.JobName then

		if BlipCloakRoom == nil then

			BlipCloakRoom = AddBlipForCoord(Config.Zones.Cloakroom.Pos.x, Config.Zones.Cloakroom.Pos.y, Config.Zones.Cloakroom.Pos.z)
			SetBlipSprite(BlipCloakRoom, Config.Zones.Cloakroom.BlipSprite)
			SetBlipColour(BlipCloakRoom, Config.Zones.Cloakroom.BlipColor)
			SetBlipAsShortRange(BlipCloakRoom, true)
			BeginTextCommandSetBlipName("STRING")
			AddTextComponentString(Config.Zones.Cloakroom.BlipName)
			EndTextCommandSetBlipName(BlipCloakRoom)

		end
	else

		if BlipCloakRoom ~= nil then
			RemoveBlip(BlipCloakRoom)
			BlipCloakRoom = nil
		end

	end

	if ESX.PlayerData.job ~= nil and ESX.PlayerData.job.name == Config.JobName and onDuty then

		BlipVehicle = AddBlipForCoord(Config.Zones.VehicleSpawner.Pos.x, Config.Zones.VehicleSpawner.Pos.y, Config.Zones.VehicleSpawner.Pos.z)
		SetBlipSprite(BlipVehicle, Config.Zones.VehicleSpawner.BlipSprite)
		SetBlipColour(BlipVehicle, Config.Zones.VehicleSpawner.BlipColor)
		SetBlipAsShortRange(BlipVehicle, true)

		BeginTextCommandSetBlipName("STRING")
		AddTextComponentString(Config.Zones.VehicleSpawner.BlipName)
		EndTextCommandSetBlipName(BlipVehicle)

		BlipSale = AddBlipForCoord(Config.Zones.Sale.Pos.x, Config.Zones.Sale.Pos.y, Config.Zones.Sale.Pos.z)
		SetBlipSprite(BlipSale, Config.Zones.Sale.BlipSprite)
		SetBlipColour(BlipSale, Config.Zones.Sale.BlipColor)
		SetBlipAsShortRange(BlipSale, true)

		BeginTextCommandSetBlipName("STRING")
		AddTextComponentString(Config.Zones.Sale.BlipName)
		EndTextCommandSetBlipName(BlipSale)

		BlipVehicleDeleter = AddBlipForCoord(Config.Zones.VehicleDeleter.Pos.x, Config.Zones.VehicleDeleter.Pos.y, Config.Zones.VehicleDeleter.Pos.z)
		SetBlipSprite(BlipVehicleDeleter, Config.Zones.VehicleDeleter.BlipSprite)
		SetBlipColour(BlipVehicleDeleter, Config.Zones.VehicleDeleter.BlipColor)
		SetBlipAsShortRange(BlipVehicleDeleter, true)

		BeginTextCommandSetBlipName("STRING")
		AddTextComponentString(Config.Zones.VehicleDeleter.BlipName)
		EndTextCommandSetBlipName(BlipVehicleDeleter)
	else

		if BlipVehicle ~= nil then
			RemoveBlip(BlipVehicle)
			BlipVehicle = nil
		end

		if BlipSale ~= nil then
			RemoveBlip(BlipSale)
			BlipSale = nil
		end

		if BlipVehicleDeleter ~= nil then
			RemoveBlip(BlipVehicleDeleter)
			BlipVehicleDeleter = nil
		end
	end
end

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if ESX.PlayerData.job ~= nil then
			local coords = GetEntityCoords(PlayerPedId())

			if ESX.PlayerData.job.name == Config.JobName then
				if onDuty then

					for k,v in pairs(Config.Zones) do
						if v ~= Config.Zones.Cloakroom then
							if(v.Type ~= -1 and GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < Config.DrawDistance) then
								DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, true, 2, false, false, false, false)
							end
						end
					end

				end

				local Cloakroom = Config.Zones.Cloakroom
				if(Cloakroom.Type ~= -1 and GetDistanceBetweenCoords(coords, Cloakroom.Pos.x, Cloakroom.Pos.y, Cloakroom.Pos.z, true) < Config.DrawDistance) then
					DrawMarker(Cloakroom.Type, Cloakroom.Pos.x, Cloakroom.Pos.y, Cloakroom.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Cloakroom.Size.x, Cloakroom.Size.y, Cloakroom.Size.z, Cloakroom.Color.r, Cloakroom.Color.g, Cloakroom.Color.b, 100, false, true, 2, false, false, false, false)
				end
			else
				Citizen.Wait(500)
			end
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1)

		if ESX.PlayerData.job ~= nil then
			local coords = GetEntityCoords(PlayerPedId())
			local isInMarker = false
			local currentZone = nil

			if ESX.PlayerData.job.name == Config.JobName then
				if onDuty then
					for k,v in pairs(Config.Zones) do
						if v ~= Config.Zones.Cloakroom then
							if(GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) <= v.Size.x) then
								isInMarker = true
								currentZone = k
							end
						end
					end
				end

				local Cloakroom = Config.Zones.Cloakroom
				if(GetDistanceBetweenCoords(coords, Cloakroom.Pos.x, Cloakroom.Pos.y, Cloakroom.Pos.z, true) <= Cloakroom.Size.x) then
					isInMarker = true
					currentZone = "Cloakroom"
				end
			end

			if (isInMarker and not HasAlreadyEnteredMarker) or (isInMarker and LastZone ~= currentZone) then
				HasAlreadyEnteredMarker = true
				LastZone = currentZone
				TriggerEvent('esx_oceansalvage:hasEnteredMarker', currentZone)
			end
			if not isInMarker and HasAlreadyEnteredMarker then
				HasAlreadyEnteredMarker = false
				TriggerEvent('esx_oceansalvage:hasExitedMarker', LastZone)
			end
		end
	end
end)

-- Action après la demande d'accés
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(10)
		if CurrentAction ~= nil then
			ESX.ShowHelpNotification(CurrentActionMsg)

			if (IsControlJustReleased(1, Keys["E"]) or IsControlJustReleased(2, Keys["RIGHT"])) and ESX.PlayerData.job ~= nil then
				local playerPed = PlayerPedId()

				if ESX.PlayerData.job.name == Config.JobName then
					if CurrentAction == 'cloakroom_menu' then

						if IsPedInAnyVehicle(playerPed, false) then
							ESX.ShowNotification(_U('in_vehicle'))
						else
							CloakRoomMenu()
						end

					elseif CurrentAction == 'vehiclespawn_menu' then

						if IsPedInAnyVehicle(playerPed, false) then
							ESX.ShowNotification(_U('in_vehicle'))
						else
							VehicleMenu()
						end

					elseif CurrentAction == 'sale' then

						TriggerServerEvent('esx_oceansalvage:startSale')
						TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_CLIPBOARD", 0, 1)

					elseif CurrentAction == 'delete_vehicle' then

						local playerPed = PlayerPedId()
						local vehicle = GetVehiclePedIsIn(playerPed, false)
						local hash = GetEntityModel(vehicle)
						local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))

						local platePrefix = Config.PlatePrefix

						if string.find(plate, platePrefix) then
							local truck = Config.Vehicles.Truck

							if hash == GetHashKey(truck.Hash) then
								if GetVehicleEngineHealth(vehicle) <= 500 or GetVehicleBodyHealth(vehicle) <= 500 then
									ESX.ShowNotification(_U('vehicle_broken'))
								else
									TriggerServerEvent('esx_vehiclelock:vehjobSup', plate, 'no')
									DeleteVehicle(vehicle)
								end
							end
						else
							ESX.ShowNotification(_U('bad_vehicle'))
						end

					end

					CurrentAction = nil
				end
			end
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(10)

		if IsControlJustReleased(1, Keys["F10"]) and ESX.PlayerData.job ~= nil and ESX.PlayerData.job.name == Config.JobName then

			if Onjob then
				StopNPCJob(true)
				RemoveBlip(Blips['NPCTargetPool'])
				Onjob = false
			else
				local playerPed = PlayerPedId()

				if IsPedInAnyVehicle(playerPed, false) and IsVehicleModel(GetVehiclePedIsIn(playerPed, false), GetHashKey("dinghy")) then
					StartNPCJob()
					Onjob = true
				else
					ESX.ShowNotification(_U('not_good_veh'))
				end
			end
		end
	end
end)

function setUniform(job)
	TriggerEvent('skinchanger:getSkin', function(skin)

		if skin.sex == 0 then
			if Config.Uniforms[job].male ~= nil then
				TriggerEvent('skinchanger:loadClothes', skin, Config.Uniforms[job].male)
			else
				ESX.ShowNotification(_U('locker_nooutfit'))
			end
		else
			if Config.Uniforms[job].female ~= nil then
				TriggerEvent('skinchanger:loadClothes', skin, Config.Uniforms[job].female)
			else
				ESX.ShowNotification(_U('locker_nooutfit'))
			end
		end

	end)
end
