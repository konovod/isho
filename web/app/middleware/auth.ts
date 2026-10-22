export default defineNuxtRouteMiddleware(async (to) => {
  const { user, fetchMe } = useAuth()

  if (!user.value) {
    await fetchMe()
  }

  if (!user.value) {
    return navigateTo('/sign_in')
  }

  // A banned account lands on the ban page instead of the dashboard; public
  // pages stay readable.
  if (user.value.ban && to.path !== '/banned') {
    return navigateTo('/banned')
  }
})
