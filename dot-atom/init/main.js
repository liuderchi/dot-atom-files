const path = require('path')

const scripts = [
  '',
]

scripts.forEach(script => {
  try {
    require(script)
  } catch (e) {
    atom.notifications.addWarning(
      `Failed to execute\n\`${path.join(__dirname, script)}\``,
      { dismissable: true }
    )
    atom.notifications.addWarning(e)
  }
})
