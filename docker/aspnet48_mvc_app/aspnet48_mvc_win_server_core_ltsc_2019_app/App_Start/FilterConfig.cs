using System.Web;
using System.Web.Mvc;

namespace Datadog_APM_AspNet48_MVC_WinServerCoreLTSC2019
{
    public class FilterConfig
    {
        public static void RegisterGlobalFilters(GlobalFilterCollection filters)
        {
            filters.Add(new HandleErrorAttribute());
        }
    }
}
