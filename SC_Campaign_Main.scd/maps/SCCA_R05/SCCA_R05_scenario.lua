version = 3
ScenarioInfo = {
    name = 'SCCA_R05',
    description = 'Campaign Map: Not Intended for Multiplayer Play',
    type = 'campaign',
    starts = true,
    preview = '',
    size = {1024, 1024},
    map = '/maps/SCCA_R05/SCCA_R05.scmap',
    save = '/maps/SCCA_R05/SCCA_R05_save.lua',
    script = '/maps/SCCA_R05/SCCA_R05_script.lua',
    Configurations = {
        ['standard'] = {
            teams = {
                { name = 'FFA', armies = {'Player','UEF','Hex5','FauxUEF',} },
            },
            customprops = {
            },
        },
    }}
