export function watchAppUpdates(workers, showUpdate) {
  let previous = workers.controller;
  workers.addEventListener('controllerchange', () => {
    const current = workers.controller;
    if (previous && current && current !== previous) showUpdate();
    previous = current;
  });
}
