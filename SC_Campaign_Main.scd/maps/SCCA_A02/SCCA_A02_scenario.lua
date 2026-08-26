version = 3
ScenarioInfo = {
    name = 'SCCA_A02',
    description = 'Campaign Map: Not Intended for Multiplayer Play',
    type = 'campaign',
    starts = true,
    preview = '',
    size = {512, 512},
    map = '/maps/SCCA_A02/SCCA_A02.scmap',
    save = '/maps/SCCA_A02/SCCA_A02_save.lua',
    script = '/maps/SCCA_A02/SCCA_A02_script.lua',
    Configurations = {
        ['standard'] = {
            teams = {
                { name = 'FFA', armies = {'Player','Cybran','NeutralCybran',} },
            },
            customprops = {
            },
        },
    }}
