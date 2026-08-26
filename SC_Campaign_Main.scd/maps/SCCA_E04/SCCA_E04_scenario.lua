version = 3
ScenarioInfo = {
    name = 'SCCA_E04',
    description = 'Campaign Map: Not Intended for Multiplayer Play',
    type = 'campaign',
    starts = true,
    preview = '',
    size = {512, 512},
    map = '/maps/SCCA_E04/SCCA_E04.scmap',
    save = '/maps/SCCA_E04/SCCA_E04_save.lua',
    script = '/maps/SCCA_E04/SCCA_E04_script.lua',
    Configurations = {
        ['standard'] = {
            teams = {
                { name = 'FFA', armies = {'Player','Cybran','Cybran_Research',} },
            },
            customprops = {
            },
        },
    }}
