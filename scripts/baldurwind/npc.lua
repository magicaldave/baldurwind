local self = require('openmw.self')
local nearby = require('openmw.nearby')
local types = require('openmw.types')
local ai = require('openmw.interfaces').AI
local core = require('openmw.core')
local async = require('openmw.async')

local didAttack = false
local hasStartedCombat = false
local hasDied = false
local isMyTurn = true

-- end their turn if not types.Actor.canMove(self)

local function getPlayer()

  for _, actor in ipairs(nearby.actors) do
    if actor.type == types.Player then
      return actor
    end
  end

end

local function startTurn()
  self:enableAI(true)
  isMyTurn = true
end

local function endTurn()
  self:enableAI(false)
  isMyTurn = false
  core.sendGlobalEvent('endTurn', {lastActor = self.object, reason = "endTurn"})
end

local function isInCombat()
  local currentPackage = ai.getActivePackage(self)

  -- What happens when they try to flee??

  if not currentPackage or currentPackage.type ~= "Combat" then return false end

  if not types.Actor.canMove(self) then
    endTurn()
    return false
  end

  return currentPackage
end

local function checkCombatTarget(aiData)
  if hasStartedCombat then return end

  -- Fix this later, when accounting for companions
  if aiData.target.recordId ~= "player" then return end

  local combatData = {
    aiTarget = aiData.target,
    aiType = aiData.type,
    source = self.object
  }

  core.sendGlobalEvent('combatInitiated', {ai = combatData, origin = self.object})

  hasStartedCombat = true
end

local function wasKilled()
  if hasDied then return true end

  local health = types.Actor.stats.dynamic["health"](self).current

  if health > 0 or not hasStartedCombat then return false end

  core.sendGlobalEvent('combatantDied', self.object)

  hasDied = true

  return true
end

local function doAttack(dt)
  if not isMyTurn then return end

  local aiData = isInCombat()

  if wasKilled() or not aiData then return end

  checkCombatTarget(aiData)

  -- migrate into a separate function for turn processing

  local attackState = self.controls.use

  if attackState == 1 then
    didAttack = true
    return
  end

  if not didAttack then return end

  didAttack = false
  endTurn()

end

return {
  engineHandlers = {
    onUpdate = doAttack,
  },
  eventHandlers = {
    isMyTurn = startTurn
  }
}
