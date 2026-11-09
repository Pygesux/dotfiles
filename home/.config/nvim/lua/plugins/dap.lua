return {
  "mfussenegger/nvim-dap",
  opts = function()
    local dap = require("dap")

    -- Nest: start with `nest start --debug --watch`, then attach
    dap.configurations.typescript = dap.configurations.typescript or {}
    table.insert(dap.configurations.typescript, {
      type = "pwa-node",
      request = "attach",
      name = "Attach to Nest (9229)",
      port = 9229,
      cwd = "${workspaceFolder}",
      sourceMaps = true,
      restart = true,
    })

    -- Vue (Vite): debug in Chrome
    local apps = {
      { name = "Portal", port = 5173, root = "${workspaceFolder}/src" },
      { name = "App", port = 5174, root = "${workspaceFolder}/src" },
    }

    for _, ft in ipairs({ "vue", "typescript", "javascript" }) do
      dap.configurations[ft] = dap.configurations[ft] or {}
      for _, app in ipairs(apps) do
        table.insert(dap.configurations[ft], {
          type = "pwa-chrome",
          request = "launch",
          name = app.name .. " (" .. app.port .. ")",
          url = "http://localhost:" .. app.port,
          webRoot = app.root,
          sourceMaps = true,
        })
      end
    end
  end,
}
