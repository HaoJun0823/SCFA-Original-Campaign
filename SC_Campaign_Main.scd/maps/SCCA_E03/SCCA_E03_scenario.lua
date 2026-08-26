version = 3
ScenarioInfo = {
    name = 'SCCA_E03',
    description = 'Campaign Map: Not Intended for Multiplayer Play',
    type = 'campaign',
    starts = true,
    preview = '',
    size = {512, 512},
    map = '/maps/SCCA_E03/SCCA_E03.scmap',
    save = '/maps/SCCA_E03/SCCA_E03_save.lua',
    script = '/maps/SCCA_E03/SCCA_E03_script.lua',
    Configurations = {
        ['standard'] = {
            teams = {
                { name = 'FFA', armies = {'Player','Aeon','Arnold',} },
            },
            customprops = {
            },
        },
    }}
