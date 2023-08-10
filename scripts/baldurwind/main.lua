local world = require('openmw.world')
local types = require('openmw.types')
local async = require('openmw.async')
local aux_util = require('openmw_aux.util')

--table including all actors in combat
-- start with npcs, and players
-- for now creatures are not technically affected though.
-- How do we determine combatants?

local combatants = {}

local function getPlayer()
  for _, ref in ipairs(world.activeActors) do
    if (ref.type == types.Player) then
      return ref
    end
  end
end

local function findEnemyCombatantIndex(enemy)
  for index, ref in ipairs(combatants) do
    if (ref == enemy) then
      return index
    end
  end
end

local function hasActiveEnemyCombatants()
  for _, ref in ipairs(combatants) do
    if (ref.type ~= types.Player) then -- Add an additional check here for non-hostile actors
      return true
    end
  end
  return false
end

local function setNextInTurnOrder()
  table.insert(combatants, table.remove(combatants, 1))
end

local function removeFromTurnOrder(actor)
  if not actor then return end
  table.remove(combatants, findEnemyCombatantIndex(actor))
  print("Removed " .. actor.recordId .. " from combatants table")
end

local function startNextTurn()
  combatants[1]:sendEvent('isMyTurn')
  print("Sending Turn Init to: " .. combatants[1].recordId)
end

local function switchTurn(endTurnData)
  print("Combatants table prior to turn shift: \n" .. aux_util.deepToString(combatants, 2))
  setNextInTurnOrder()
  print("Combatants table after turn shift: \n" .. aux_util.deepToString(combatants, 2))
  -- This is dumb, and could potentially break if another actor enters combat whilst one is taking a turn
  -- I think?
  -- if combatants[1] == endTurnData.lastActor then setNextInTurnOrder() end
  startNextTurn()
end

local function notifyActorTurnOrderChanged(actor, state)
  if state == "added" then
    print(actor.recordId .. " has joined the fight!")
  elseif state == "removed" then
    print(actor.recordId .. " is no longer in the fight!")
  end
end

local function declareFightStart(enemyInfo)
  getPlayer():sendEvent('declareFight', enemyInfo.ai)
  print("Combatants table prior to adding actor: \n" .. aux_util.deepToString(combatants, 2))

  -- Newly added actors will take their turns first, so let's put them at the top. Otherwise,
  -- They take two turns when the turn shift occurs.
  table.insert(combatants, 1, enemyInfo.origin)
  print("Combatants table after adding actor: \n" .. aux_util.deepToString(combatants, 2))
  notifyActorTurnOrderChanged(enemyInfo.origin, "added")
end

local function combatantDied(actor)
  -- When the actor dies, remove them from turn order.
  -- The player themselves should generate an `endTurn` event when the actor is killed.
  -- Do they die first, or does your turn end first?
  -- The actor should remove themselves from turn order, first.
  removeFromTurnOrder(actor)
  -- Then process the next turn.

  -- Only terminate combat, if there are no enemies to keep fighting!
  if hasActiveEnemyCombatants() then startNextTurn() return end

  getPlayer():sendEvent('declareFightEnd')
end

local function initializeCombatants(player)
  table.insert(combatants, player)
  notifyActorTurnOrderChanged(player, "added")
end

return {
    interfaceName = 's3turnsmain',
    interface = {
      combatants = combatants,
      version = 001,
    },
    engineHandlers = {
      onPlayerAdded = initializeCombatants
    },
    eventHandlers = {
      endTurn = switchTurn,
      -- onLoad = initializeCombatants,
      combatInitiated = declareFightStart,
      endedCombat = declareFightEnd,
      combatantDied = combatantDied
    }
}
