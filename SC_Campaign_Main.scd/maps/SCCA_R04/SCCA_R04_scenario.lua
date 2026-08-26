version = 3
ScenarioInfo = {
    name = 'SCCA_R04',
    description = 'Campaign Map: Not Intended for Multiplayer Play',
    type = 'campaign',
    starts = true,
    preview = '',
    size = {1024, 1024},
    map = '/maps/SCCA_R04/SCCA_R04.scmap',
    save = '/maps/SCCA_R04/SCCA_R04_save.lua',
    script = '/maps/SCCA_R04/SCCA_R04_script.lua',
    Configurations = {
        ['standard'] = {
            teams = {
                { name = 'FFA', armies = {'Player','Aeon','Civilian','Neutral',} },
            },
            customprops = {
            },
        },
    }}
