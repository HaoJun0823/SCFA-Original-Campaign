version = 3
ScenarioInfo = {
    name = 'SCCA_A06',
    description = 'Campaign Map: Not Intended for Multiplayer Play',
    type = 'campaign',
    starts = true,
    preview = '',
    size = {1024, 1024},
    map = '/maps/SCCA_E06/SCCA_E06.scmap',
    save = '/maps/SCCA_A06/SCCA_A06_save.lua',
    script = '/maps/SCCA_A06/SCCA_A06_script.lua',
    Configurations = {
        ['standard'] = {
            teams = {
                { name = 'FFA', armies = {'Player','UEF','Cybran','Aeon','Neutral',} },
            },
            customprops = {
            },
        },
    }}
