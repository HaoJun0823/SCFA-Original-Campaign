version = 3
ScenarioInfo = {
    name = 'SCCA_E02',
    description = 'Campaign Map: Not Intended for Multiplayer Play',
    type = 'campaign',
    starts = true,
    preview = '',
    size = {512, 512},
    map = '/maps/SCCA_E02/SCCA_E02.scmap',
    save = '/maps/SCCA_E02/SCCA_E02_save.lua',
    script = '/maps/SCCA_E02/SCCA_E02_script.lua',
    Configurations = {
        ['standard'] = {
            teams = {
                { name = 'FFA', armies = {'Player','Aeon','AllyResearch','AllyCivilian','AeonNeutral',} },
            },
            customprops = {
            },
        },
    }}
