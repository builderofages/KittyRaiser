-- MeshDiagnostic.server.lua  v1
-- Logs every mesh template's MeshId state at boot so we know which assets
-- have actual geometry vs which are empty wrappers (rectangles).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

task.spawn(function()
    -- Wait for MeshLoader to finish
    for _ = 1, 60 do
        if _G.KittyRaiserMeshes then break end
        task.wait(0.5)
    end
    if not _G.KittyRaiserMeshes then
        warn("[MeshDiagnostic] _G.KittyRaiserMeshes never populated")
        return
    end

    print("===== MESH DIAGNOSTIC =====")
    local total, withMesh, empty = 0, 0, 0
    for name, entry in pairs(_G.KittyRaiserMeshes) do
        total = total + 1
        local tmpl = entry.meshTemplate
        if tmpl and tmpl:IsA("MeshPart") and tmpl.MeshId and tmpl.MeshId ~= "" then
            withMesh = withMesh + 1
            print(string.format("[MeshDiag]  ✓ %s — MeshId=%s, Size=%s",
                name, tostring(tmpl.MeshId):sub(-30), tostring(tmpl.Size)))
        else
            empty = empty + 1
            warn(string.format("[MeshDiag]  ✗ %s — NO MESH (template=%s)", name, tostring(tmpl)))
        end
    end
    print(string.format("===== %d/%d meshes have actual geometry, %d are empty/missing =====",
        withMesh, total, empty))
end)
