package com.appjava;

import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

import javax.naming.NamingException;

//new
import com.mysql.cj.jdbc.MysqlDataSource;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

public final class QueryEmployees {
	private static final Logger logger = LogManager.getLogger(QueryEmployees.class);

    public static void query(PrintWriter out) throws NamingException {
    	MysqlDataSource ds = null;
        Connection connect = null;
        Statement statement = null;
        ResultSet resultSet = null;

        try {
            // Create a new DataSource (MySQL specifically)
            // and provide the relevant information to be used by Tomcat.
            ds = new MysqlDataSource();
            ds.setUrl("jdbc:mysql://mysql-test:3306/employees");
            ds.setUser("lab");
            ds.setPassword("lab");

	        connect = ds.getConnection();

	        // Create the statement to be used to get the results.
	        statement = connect.createStatement();
	        String query = "select distinct first_name FROM employees where first_name='Georgi'";

	        // Execute the query and get the result set.
	        resultSet = statement.executeQuery(query);
	        out.println("<strong>Printing result using DataSource...</strong><br>");

	        while (resultSet.next()) {
	        	String employeeName = resultSet.getString("first_name");

	        	out.println("Name: " + employeeName + "<br>");
	        }

	        logger.info("log for traceID correlation");

    } catch (SQLException e) { e.printStackTrace(out);
    } finally {
        // Close the connection and release the resources used.
    	try { resultSet.close(); } catch (SQLException e) { e.printStackTrace(out); }
        try { statement.close(); } catch (SQLException e) { e.printStackTrace(out); }
        try { connect.close(); } catch (SQLException e) { e.printStackTrace(out); }
    }
    }

}
