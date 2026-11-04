
-- omarchy-typography >>> (window-title font; removed by `omarchy-typography uninstall`)
do
  local typography = os.getenv("HOME") .. "/.config/hypr/typography.lua"
  local file = io.open(typography, "r")
  if file then file:close(); dofile(typography) end
end
-- <<< omarchy-typography
