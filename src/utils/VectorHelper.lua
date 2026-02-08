-- =========================================================
-- TODO / FUTURE VISION
-- =========================================================
-- MATH OPERATIONS:
-- [x] 2D and 3D distance calculations
-- [x] Scalar and vector linear interpolation (lerp)
-- [x] Value clamping (scalar and vector)
-- [x] Dot product and cross product
-- [ ] Smoothstep / ease-in-out interpolation for smoother NPC movement
-- [ ] Bezier curve evaluation for curved NPC walking paths
--
-- GEOMETRY:
-- [x] Point-in-circle and point-in-rectangle tests
-- [x] Random point generation in circle and rectangle regions
-- [x] Angle calculation between two points
-- [x] Vector normalization and rotation
-- [x] Perpendicular and reflection vectors
-- [x] MoveTowards with max distance delta
-- [ ] Point-in-polygon test for irregular NPC activity zones
-- [ ] Line segment intersection for path collision detection
-- [ ] Closest point on line segment (for NPC-to-road snapping)
--
-- PERFORMANCE:
-- [ ] Squared distance variants to avoid sqrt in hot paths
-- [ ] Lookup table for sin/cos in frequently called rotation code
-- =========================================================

-- =========================================================
-- Vector Helper Utilities
-- =========================================================
-- Math utilities for vector operations
-- =========================================================

VectorHelper = {}

function VectorHelper.distance2D(x1, z1, x2, z2)
    local dx = x2 - x1
    local dz = z2 - z1
    return math.sqrt(dx * dx + dz * dz)
end

function VectorHelper.distance3D(x1, y1, z1, x2, y2, z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function VectorHelper.angleBetween(x1, z1, x2, z2)
    return math.atan2(z2 - z1, x2 - x1)
end

function VectorHelper.normalize(x, z)
    local length = math.sqrt(x * x + z * z)
    if length > 0 then
        return x / length, z / length
    end
    return 0, 0
end

function VectorHelper.rotateVector(x, z, angle)
    local cos = math.cos(angle)
    local sin = math.sin(angle)
    return x * cos - z * sin, x * sin + z * cos
end

function VectorHelper.lerp(start, finish, t)
    return start + (finish - start) * t
end

function VectorHelper.lerpVector(x1, z1, x2, z2, t)
    return VectorHelper.lerp(x1, x2, t), VectorHelper.lerp(z1, z2, t)
end

function VectorHelper.isPointInCircle(px, pz, cx, cz, radius)
    local dx = px - cx
    local dz = pz - cz
    return (dx * dx + dz * dz) <= (radius * radius)
end

function VectorHelper.isPointInRectangle(px, pz, rx1, rz1, rx2, rz2)
    return px >= math.min(rx1, rx2) and px <= math.max(rx1, rx2) and
           pz >= math.min(rz1, rz2) and pz <= math.max(rz1, rz2)
end

function VectorHelper.getRandomPointInCircle(cx, cz, radius)
    local angle = math.random() * math.pi * 2
    local distance = math.random() * radius
    return cx + math.cos(angle) * distance, cz + math.sin(angle) * distance
end

function VectorHelper.getRandomPointInRectangle(x1, z1, x2, z2)
    local minX = math.min(x1, x2)
    local maxX = math.max(x1, x2)
    local minZ = math.min(z1, z2)
    local maxZ = math.max(z1, z2)
    
    return minX + math.random() * (maxX - minX), minZ + math.random() * (maxZ - minZ)
end

function VectorHelper.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function VectorHelper.clampVector(x, z, maxLength)
    local length = math.sqrt(x * x + z * z)
    if length > maxLength then
        local scale = maxLength / length
        return x * scale, z * scale
    end
    return x, z
end

function VectorHelper.dotProduct(x1, z1, x2, z2)
    return x1 * x2 + z1 * z2
end

function VectorHelper.crossProduct(x1, z1, x2, z2)
    return x1 * z2 - z1 * x2
end

function VectorHelper.getPerpendicular(x, z)
    return -z, x
end

function VectorHelper.reflectVector(x, z, normalX, normalZ)
    local dot = VectorHelper.dotProduct(x, z, normalX, normalZ)
    return x - 2 * dot * normalX, z - 2 * dot * normalZ
end

function VectorHelper.moveTowards(currentX, currentZ, targetX, targetZ, maxDistanceDelta)
    local dx = targetX - currentX
    local dz = targetZ - currentZ
    local distance = math.sqrt(dx * dx + dz * dz)
    
    if distance <= maxDistanceDelta or distance == 0 then
        return targetX, targetZ
    end
    
    return currentX + dx / distance * maxDistanceDelta, currentZ + dz / distance * maxDistanceDelta
end