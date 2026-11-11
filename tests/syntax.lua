local ok_all = true
for _, f in ipairs(arg) do
  local fn, err = loadfile(f)
  if not fn then print("FEHLER " .. err); ok_all = false else print("OK     " .. f) end
end
if not ok_all then os.exit(1) end
