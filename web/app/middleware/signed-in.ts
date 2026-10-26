// Messages stay readable for a banned account: only the composer is hidden and
// the API blocks sending. The regular `auth` middleware sends banned users to
// `/banned`, which would take their inbox away.
export default defineNuxtRouteMiddleware(async () => {
  const { user, fetchMe } = useAuth()

  if (!user.value) {
    await fetchMe()
  }

  if (!user.value) {
    return navigateTo('/sign_in')
  }
})
