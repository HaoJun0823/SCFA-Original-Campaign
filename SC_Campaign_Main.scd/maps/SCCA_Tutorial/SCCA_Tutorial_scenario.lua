version = 3
ScenarioInfo = {
    name = 'scca_tutorial',
    description = 'Supreme Commander Tutorial',
    type = 'campaign',
    starts = true,
    preview = '',
    size = {512, 512},
    map = '/maps/SCMP_019/SCMP_019.scmap',
    save = '/maps/scca_tutorial/scca_tutorial_save.lua',
    script = '/maps/scca_tutorial/scca_tutorial_script.lua',
    Configurations = {
        ['standard'] = {
            teams = {
                { name = 'FFA', armies = {'Player',} },
            },
            customprops = {
            },
        },
    }}
