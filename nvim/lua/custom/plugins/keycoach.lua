return {
  {
    dir = vim.fn.stdpath 'config', -- tells lazy this is a local plugin
    name = 'keycoach-hud',
    lazy = false,
    priority = 1000,
    config = function()
      require('custom.keycoach_hud').setup()
    end,
  },
}
