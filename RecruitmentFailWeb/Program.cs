using MicrosoftAnnotations = Microsoft.AspNetCore.Mvc.DataAnnotations;

using RecruitmentFailWeb.Models.DataAnnotations;
using RecruitmentFailWeb.Util;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCognitoIdentity(); // Hook up Amazon Cognito user store.  Order matters here.  Do this first!

// Cancel redirection of API calls and instead return 401 Unauthorized error.
builder.Services.ConfigureApplicationCookie(
    options =>
    {
        options.Events.OnRedirectToLogin += context =>
        {
            String path = context.Request.Path;

            if (path.StartsWith("/api"))
            {
                context.Response.Headers["Location"] = path;
                context.Response.StatusCode = 401;
            }

            return Task.CompletedTask;
        };
    }
);

// Add services to the container.
builder.Services.AddControllersWithViews(
    options => options.Filters.Add(typeof(ExceptionLoggerAttribute)) // default response for exceptions
    );

builder.Services.AddDistributedMemoryCache();

builder.Services.AddSession(options =>
{
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
});

builder.Services.AddSingleton<MicrosoftAnnotations.IValidationAttributeAdapterProvider, ValidationAttributeAdapterProvider>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
}
app.UseStaticFiles();

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.UseSession();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
