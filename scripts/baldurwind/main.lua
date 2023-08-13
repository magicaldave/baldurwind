local world = require('openmw.world')
local types = require('openmw.types')
local async = require('openmw.async')
local aux_util = require('openmw_aux.util')
local common = require('scripts.baldurwind.common')

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
  if not actor or actor.type == types.Player then return end
  table.remove(combatants, findEnemyCombatantIndex(actor))
  common.debugMePls("Removed " .. actor.recordId .. " from combatants table")
end

local function startNextTurn()
  combatants[1]:sendEvent('isMyTurn', combatants)
  common.debugMePls("Sending Turn Init to: " .. combatants[1].recordId)
end

local function switchTurn()
  if #combatants == 1 then return end
  common.debugMePls("Combatants table prior to turn shift: \n" .. aux_util.deepToString(combatants, 2))
  setNextInTurnOrder()
  common.debugMePls("Combatants table after turn shift: \n" .. aux_util.deepToString(combatants, 2))
  startNextTurn()
end

local function declareFightStart(enemyInfo)
  getPlayer():sendEvent('declareFight', enemyInfo.ai)

  common.debugMePls("Combatants table prior to adding actor: \n" .. aux_util.deepToString(combatants, 2))

  -- Newly added actors will take their turns first, so let's put them at the top. Otherwise,
  -- They take two turns when the turn shift occurs.
  table.insert(combatants, 1, enemyInfo.origin)

  common.debugMePls("Combatants table after adding actor: \n" .. aux_util.deepToString(combatants, 2))

end

local function combatantDied(actor)
  -- The actor should remove themselves from turn order, first.
  removeFromTurnOrder(actor)
  -- Then process the next turn.
  -- Unless there are no enemies to keep fighting!
  if hasActiveEnemyCombatants() then startNextTurn() return end

  getPlayer():sendEvent('declareFightEnd')
end

local function initializeCombatants(player)
  table.insert(combatants, player)
  -- I suppose this is where, on load, we should figure out whether a fight was in progress or not.
  -- That'll be fun.
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
      combatantDied = combatantDied
    }
}
