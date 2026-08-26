version = 3
ScenarioInfo = {
    name = 'SCCA_R02',
    description = 'Campaign Map: Not Intended for Multiplayer Play',
    type = 'campaign',
    starts = true,
    preview = '',
    size = {512, 512},
    map = '/maps/SCCA_R02/SCCA_R02.scmap',
    save = '/maps/SCCA_R02/SCCA_R02_save.lua',
    script = '/maps/SCCA_R02/SCCA_R02_script.lua',
    Configurations = {
        ['standard'] = {
            teams = {
                { name = 'FFA', armies = {'Player','Aeon','CybranJanus','Civilian','FakeAeon','FakeJanus',} },
            },
            customprops = {
            },
        },
    }}
