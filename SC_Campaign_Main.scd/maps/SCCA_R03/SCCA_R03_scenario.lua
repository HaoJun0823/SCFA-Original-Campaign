version = 3
ScenarioInfo = {
    name = 'SCCA_R03',
    description = 'Campaign Map: Not Intended for Multiplayer Play',
    type = 'campaign',
    starts = true,
    preview = '',
    size = {512, 512},
    map = '/maps/SCCA_E04/SCCA_E04.scmap',
    save = '/maps/SCCA_R03/SCCA_R03_save.lua',
    script = '/maps/SCCA_R03/SCCA_R03_script.lua',
    Configurations = {
        ['standard'] = {
            teams = {
                { name = 'FFA', armies = {'Player','UEF','BrackmanBase','Civilian','CybranCloaked',} },
            },
            customprops = {
            },
        },
    }}
