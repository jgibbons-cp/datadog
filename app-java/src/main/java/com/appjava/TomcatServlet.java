package com.appjava;

import java.io.IOException;
import java.io.PrintWriter;

import javax.naming.NamingException;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

@SuppressWarnings("serial")
public class TomcatServlet extends HttpServlet {

    @Override
    public void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        response.setContentType("text/html");
        PrintWriter out = response.getWriter();

        if (request.getParameter("jdbc_query") != null) {
            try {
              // Use this class if you have created the context.xml file.
              String name = request.getParameter("last_name");
              QueryEmployees queryEmployees = new QueryEmployees();
              queryEmployees.query(name, out);
            } catch (NamingException e) {
                e.printStackTrace();
            }
        }
    }
}
