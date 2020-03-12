ESX = nil
local PlayersSale = {}

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterServerEvent('esx_oceansalvage:GiveItem')
AddEventHandler('esx_oceansalvage:GiveItem', function()
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)

	local Quantity = xPlayer.getInventoryItem(Config.Zones.Sale.ItemRequires).count

	if Quantity >= 15 then
		xPlayer.showNotification(_U('stop_npc'))
	else
		local amount = Config.Zones.Sale.ItemAdd
		local item = Config.Zones.Sale.ItemDb_name
		xPlayer.addInventoryItem(item, amount)
		xPlayer.showNotification(_U('salvage_collected'))
	end

end)

local function Sale(source)

	SetTimeout(Config.Zones.Sale.ItemTime, function()

		if PlayersSale[source] == true then

			local _source = source
			local xPlayer = ESX.GetPlayerFromId(_source)

			local Quantity = xPlayer.getInventoryItem(Config.Zones.Sale.ItemRequires).count

			if Quantity < Config.Zones.Sale.ItemRemove then
				xPlayer.showNotification(_U('sell_nomorebills'))
				PlayersSale[_source] = false
			else
				local amount = Config.Zones.Sale.ItemRemove
				local item = Config.Zones.Sale.ItemRequires

				Citizen.Wait(1500)
				xPlayer.removeInventoryItem(item, amount)
				xPlayer.addMoney(Config.Zones.Sale.ItemPrice)
				xPlayer.showNotification(_U('sell_earned', ESX.Math.GroupDigits(Config.Zones.Sale.ItemPrice)))
				Sale(_source)
			end

		end
	end)
end

RegisterServerEvent('esx_oceansalvage:startSale')
AddEventHandler('esx_oceansalvage:startSale', function()
	local _source = source

	if PlayersSale[_source] == false then
		xPlayer.showNotification(_U('sell_nobills'))
		PlayersSale[_source] = false
	else
		PlayersSale[_source] = true
		xPlayer.showNotification(_U('sell_cashing'))
		Sale(_source)
	end
end)

RegisterServerEvent('esx_oceansalvage:stopSale')
AddEventHandler('esx_oceansalvage:stopSale', function()
	local _source = source

	if PlayersSale[_source] == true then
		PlayersSale[_source] = false
	else
		PlayersSale[_source] = true
	end
end)
